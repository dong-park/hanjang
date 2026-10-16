#!/usr/bin/env python3
"""한장! 방 관리 서비스. 방마다 헤드리스 Godot 프로세스를 띄우고, 한 포트(기본 8070)로 목록·입장·웹소켓 중계를 맡는다.

  POST /api/rooms        {"name": "방 이름(12자까지)", "public": true}  -> {code, name, public, path, link}
  GET  /api/rooms        공개 방만: [{code, name, players, capacity, state, joinable}]
  GET  /api/rooms/CODE   코드로 입장 확인 (공개·비공개 모두). 없으면 404 「방을 못 찾았어요」
  GET  /ws/CODE          웹소켓 -> 그 방 프로세스로 중계 (터널은 이 한 포트만 열면 된다)
  GET  /, /파일          build/web (웹 빌드)을 그대로 서빙한다. 터널 주소 하나로 게임 페이지와 위 API가 같이 열린다.

표준 라이브러리만 쓴다. 서버가 꺼지면 방은 되살리지 않는다.
"""
import asyncio, collections, json, os, random, re, secrets, shlex, signal, sys, time, urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB_DIR = os.environ.get("HANJANG_WEB_DIR", os.path.join(ROOT, "build", "web"))
MIME = {".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".wasm": "application/wasm",
        ".png": "image/png", ".pck": "application/octet-stream", ".json": "application/json; charset=utf-8",
        ".css": "text/css; charset=utf-8", ".ico": "image/x-icon", ".svg": "image/svg+xml"}

# 방 프로세스를 띄우는 명령 줄. 형식은 이 한 곳에만 둔다 ({port}가 방 포트로 바뀐다).
# 환경변수 HANJANG_ROOM_CMD로 바꿀 수 있다(시험은 가짜 방을 쓴다).
ROOM_CMD = os.environ.get(
    "HANJANG_ROOM_CMD",
    "engine/Godot.app/Contents/MacOS/Godot --headless --path game -- --host --dedicated --port={port} "
    "--code={code} --secret={secret} --public={public} --room-name={name}",
)
MAX_ROOMS = int(os.environ.get("HANJANG_MAX_ROOMS", "6"))
IDLE_SECONDS = float(os.environ.get("HANJANG_IDLE_SECONDS", "60"))
PORT_BASE = int(os.environ.get("HANJANG_ROOM_PORT_BASE", "7800"))
RATE_MAX = int(os.environ.get("HANJANG_RATE_MAX", "20"))  # 한 주소가 RATE_WINDOW초 안에 이만큼 연결하면 막는다
RATE_WINDOW = float(os.environ.get("HANJANG_RATE_WINDOW", "1"))
RATE_BLOCK = float(os.environ.get("HANJANG_RATE_BLOCK", "60"))
LOG_PATH = os.environ.get("HANJANG_LOG", "")  # 비우면 표준 오류
CAPACITY = 4
NAME_MAX = 12
# 방 프로세스 출력 줄로 방 상태를 안다 (game/net/room.gd)
PLAYING_MARKS = ("START_OK", "GAME_STARTED")
WAITING_MARKS = ("BACK_TO_LOBBY",)

MSG_FULL = "지금은 방이 가득 찼어요"
MSG_NOT_FOUND = "방을 못 찾았어요"
MSG_NAME = "방 이름은 1~12자로 적어 주세요"
MSG_EMPTY = "이름을 적어 주세요"
MSG_EMOJI = "이모지는 쓸 수 없어요"
MSG_BANNED = "쓸 수 없는 말이 들어 있어요"
MSG_RATE = "잠시 후에 다시 해 주세요"
BANNED = ("씨발", "시발", "병신", "개새끼", "좆", "fuck", "shit")  # game/net/room.gd BANNED 와 같은 목록


def name_problem(name):
    """방 이름 규칙(game/net/room.gd name_problem 과 같다). 괜찮으면 빈 문자열."""
    if not name:
        return MSG_EMPTY
    if len(name) > NAME_MAX:
        return MSG_NAME
    if any(ord(c) >= 0x1F000 or 0x2600 <= ord(c) <= 0x27BF or ord(c) in (0xFE0F, 0x200D) for c in name):
        return MSG_EMOJI
    if any(w in name.lower() for w in BANNED):
        return MSG_BANNED
    return ""


def mask_ip(ip):
    """로그에는 주소 앞 두 칸만 남긴다 (IPv4 a.b.x.x, IPv6 앞 두 묶음)."""
    if ":" in ip:
        return ":".join(ip.split(":")[:2]) + ":x"
    return ".".join(ip.split(".")[:2]) + ".x.x"


def log(event, code="", ip="", err=""):
    """방 코드, 이벤트, 오류 종류만 적는다. 닉네임·방 이름·전체 주소는 쓰지 않는다."""
    line = time.strftime("%Y-%m-%dT%H:%M:%S") + " " + event
    for k, v in (("code", code), ("ip", mask_ip(ip) if ip else ""), ("err", err)):
        if v:
            line += f" {k}={v}"
    if LOG_PATH:
        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    else:
        print(line, file=sys.stderr, flush=True)


class Limiter:
    """주소별 연결 제한. 터널 뒤에서는 CF-Connecting-IP 로 주소를 안다."""

    def __init__(self):
        self.hits = collections.defaultdict(collections.deque)
        self.blocked = {}

    def allow(self, ip):
        now = time.monotonic()
        until = self.blocked.get(ip)
        if until is not None:
            if now < until:
                return False
            del self.blocked[ip]
        q = self.hits[ip]
        q.append(now)
        while q and now - q[0] > RATE_WINDOW:
            q.popleft()
        if len(q) >= RATE_MAX:
            self.blocked[ip] = now + RATE_BLOCK
            del self.hits[ip]
            log("RATE_BLOCK", ip=ip)
            return False
        if len(self.hits) > 5000:  # 오래된 주소 기록을 비운다
            for k in [k for k, v in self.hits.items() if not v or now - v[-1] > RATE_WINDOW]:
                del self.hits[k]
        return True


LIMITER = Limiter()



class Room:
    def __init__(self, code, name, public, port):
        self.code, self.name, self.public, self.port = code, name, public, port
        self.secret = secrets.token_hex(8)
        self.state = "waiting"
        self.players = 0
        self.proc = None
        self.empty_since = time.monotonic()
        self.closed = False

    def info(self):
        return {
            "code": self.code, "name": self.name, "players": self.players, "capacity": CAPACITY,
            "state": self.state, "joinable": self.state == "waiting" and self.players < CAPACITY,
        }


class Manager:
    def __init__(self):
        self.rooms = {}

    def free_port(self):
        used = {r.port for r in self.rooms.values()}
        return next(p for p in range(PORT_BASE, PORT_BASE + MAX_ROOMS + 50) if p not in used)

    def new_code(self):
        while True:
            c = "%04d" % random.randint(0, 9999)
            if c not in self.rooms:
                return c

    async def create(self, name, public):
        if len(self.rooms) >= MAX_ROOMS:
            return None
        room = Room(self.new_code(), name, public, self.free_port())
        self.rooms[room.code] = room  # 띄우는 동안 자리를 먼저 잡아 한도를 넘지 않게 한다
        q = shlex.quote
        argv = shlex.split(ROOM_CMD.format(port=room.port, code=room.code, secret=room.secret,
                                           public=int(public), name=q(name)))
        try:
            room.proc = await asyncio.create_subprocess_exec(
                *argv, cwd=ROOT, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
                stdin=asyncio.subprocess.DEVNULL)
        except OSError:
            del self.rooms[room.code]
            raise
        log("ROOM_OPEN", room.code)
        asyncio.create_task(self.watch_output(room))
        asyncio.create_task(self.reap_idle(room))
        return room

    async def watch_output(self, room):
        while True:
            line = await room.proc.stdout.readline()
            if not line:
                break
            s = line.decode("utf-8", "replace")
            if any(m in s for m in PLAYING_MARKS):
                room.state = "playing"
            elif any(m in s for m in WAITING_MARKS):
                room.state = "waiting"
        await room.proc.wait()
        self.drop(room)  # 프로세스가 스스로 끝나도 목록에서 지운다

    async def reap_idle(self, room):
        # 접속자 0명이 IDLE_SECONDS 이어지면 끝낸다 (대기·판 중 모두 같다)
        while not room.closed:
            await asyncio.sleep(min(1.0, IDLE_SECONDS / 4))
            if room.players > 0:
                room.empty_since = None
            elif room.empty_since is None:
                room.empty_since = time.monotonic()
            elif time.monotonic() - room.empty_since >= IDLE_SECONDS:
                await self.close(room)

    def drop(self, room):
        if not room.closed:
            log("ROOM_CLOSE", room.code)
        room.closed = True
        self.rooms.pop(room.code, None)

    async def close(self, room):
        self.drop(room)
        if room.proc and room.proc.returncode is None:
            room.proc.terminate()
            try:
                await asyncio.wait_for(room.proc.wait(), 5)
            except asyncio.TimeoutError:
                room.proc.kill()

    async def shutdown(self):
        for r in list(self.rooms.values()):
            await self.close(r)


M = Manager()


def reply(status, body):
    reason = {200: "OK", 201: "Created", 400: "Bad Request", 404: "Not Found", 429: "Too Many Requests", 503: "Service Unavailable"}[status]
    data = json.dumps(body, ensure_ascii=False).encode()
    head = (f"HTTP/1.1 {status} {reason}\r\nContent-Type: application/json; charset=utf-8\r\n"
            f"Content-Length: {len(data)}\r\nAccess-Control-Allow-Origin: *\r\n"
            f"Access-Control-Allow-Headers: content-type\r\nConnection: close\r\n\r\n").encode()
    return head + data


def static_reply(path, head_only=False):
    """build/web 파일 응답. 폴더 밖으로 나가는 주소와 없는 파일은 None(404)."""
    rel = "index.html" if path == "/" else os.path.normpath(urllib.parse.unquote(path).lstrip("/"))
    full = os.path.realpath(os.path.join(WEB_DIR, rel))
    if not full.startswith(os.path.realpath(WEB_DIR) + os.sep) or not os.path.isfile(full):
        return None
    with open(full, "rb") as f:
        data = f.read()
    ctype = MIME.get(os.path.splitext(full)[1].lower(), "application/octet-stream")
    head = (f"HTTP/1.1 200 OK\r\nContent-Type: {ctype}\r\nContent-Length: {len(data)}\r\n"
            f"Cache-Control: no-cache\r\nConnection: close\r\n\r\n").encode()
    return head if head_only else head + data


async def read_head(reader):
    raw = await reader.readuntil(b"\r\n\r\n")
    lines = raw.decode("latin-1").split("\r\n")
    method, path, _ = lines[0].split(" ", 2)
    headers = {}
    for ln in lines[1:]:
        if ":" in ln:
            k, v = ln.split(":", 1)
            headers[k.strip().lower()] = v.strip()
    return raw, method, path.split("?")[0], headers


async def pipe(src, dst):
    try:
        while data := await src.read(65536):
            dst.write(data)
            await dst.drain()
    except (ConnectionError, asyncio.CancelledError):
        pass
    finally:
        try:
            dst.close()
        except Exception:
            pass


def ws_head(raw):
    """웹소켓 요청 머리를 방 서버가 받는 형태로 맞춘다. HTTP/2로 들어온 요청은 Cloudflare가 Upgrade 줄을 떼고
    Connection: keep-alive로 넘기므로, Godot가 받도록 Upgrade/Connection 줄을 다시 붙인다."""
    lines = raw.split(b"\r\n")
    keep = [ln for ln in lines[:-2] if not ln.lower().startswith((b"connection:", b"upgrade:"))]
    return b"\r\n".join(keep + [b"Upgrade: websocket", b"Connection: Upgrade", b"", b""])


async def proxy(room, raw, reader, writer, ip):
    raw = ws_head(raw)
    up = None
    for _ in range(50):  # 방 프로세스가 포트를 여는 동안 최대 5초 기다린다
        try:
            up, upw = await asyncio.open_connection("127.0.0.1", room.port)
            break
        except OSError:
            await asyncio.sleep(0.1)
    if up is None:
        writer.write(reply(503, {"error": MSG_NOT_FOUND}))
        return
    room.players += 1
    log("WS_OPEN", room.code, ip)
    try:
        upw.write(raw)
        await asyncio.gather(pipe(reader, upw), pipe(up, writer))
    finally:
        room.players = max(0, room.players - 1)
        log("WS_CLOSE", room.code, ip)


async def handle(reader, writer):
    try:
        raw, method, path, headers = await asyncio.wait_for(read_head(reader), 10)
        ip = headers.get("cf-connecting-ip") or (writer.get_extra_info("peername") or ("?",))[0]
        if not LIMITER.allow(ip):
            writer.write(reply(429, {"error": MSG_RATE}))
        elif method == "OPTIONS":
            writer.write(reply(200, {}))
        elif m := re.fullmatch(r"/ws/(\d{4})", path):
            room = M.rooms.get(m.group(1))
            if room is None:
                writer.write(reply(404, {"error": MSG_NOT_FOUND}))
            else:
                await proxy(room, raw, reader, writer, ip)
        elif path == "/api/rooms" and method == "GET":
            writer.write(reply(200, [r.info() for r in M.rooms.values() if r.public]))
        elif path == "/api/rooms" and method == "POST":
            body = json.loads(await reader.readexactly(int(headers.get("content-length", "0"))) or b"{}")
            name = str(body.get("name", "")).strip()
            if problem := name_problem(name):
                writer.write(reply(400, {"error": problem}))
            else:
                room = await M.create(name, bool(body.get("public", True)))
                if room is None:
                    writer.write(reply(503, {"error": MSG_FULL}))
                else:
                    scheme = headers.get("x-forwarded-proto", "http").split(",")[0].strip()  # 터널 뒤에서는 https
                    base = os.environ.get("HANJANG_PUBLIC_BASE", f"{scheme}://" + headers.get("host", "localhost"))
                    writer.write(reply(201, {"code": room.code, "name": room.name, "public": room.public,
                                             "secret": room.secret, "path": f"/ws/{room.code}", "link": f"{base}/?room={room.code}"}))
        elif m := re.fullmatch(r"/api/rooms/(\d{4})", path):
            room = M.rooms.get(m.group(1))
            writer.write(reply(200, {**room.info(), "secret": room.secret}) if room else reply(404, {"error": MSG_NOT_FOUND}))
        elif method in ("GET", "HEAD") and (page := static_reply(path, method == "HEAD")):
            writer.write(page)
        else:
            writer.write(reply(404, {"error": "없는 주소예요"}))
        await writer.drain()
    except (asyncio.IncompleteReadError, ConnectionError, ValueError, json.JSONDecodeError):
        pass
    except Exception as e:  # 한 연결의 오류가 서비스를 멈추지 않게 한다
        log("ERROR", err=type(e).__name__)
    finally:
        try:
            writer.close()
        except Exception:
            pass


async def main(port):
    server = await asyncio.start_server(handle, "0.0.0.0", port)
    stop = asyncio.Event()
    for s in (signal.SIGINT, signal.SIGTERM):
        asyncio.get_running_loop().add_signal_handler(s, stop.set)
    print("MANAGER_READY", port, flush=True)
    await stop.wait()
    server.close()
    await M.shutdown()


if __name__ == "__main__":
    asyncio.run(main(int(sys.argv[1]) if len(sys.argv) > 1 else 8070))

