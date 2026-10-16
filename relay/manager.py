#!/usr/bin/env python3
"""한장! 방 관리 서비스. 방마다 헤드리스 Godot 프로세스를 띄우고, 한 포트(기본 8070)로 목록·입장·웹소켓 중계를 맡는다.

  POST /api/rooms        {"name": "방 이름(12자까지)", "public": true}  -> {code, name, public, path, link}
  GET  /api/rooms        공개 방만: [{code, name, players, capacity, state, joinable}]
  GET  /api/rooms/CODE   코드로 입장 확인 (공개·비공개 모두). 없으면 404 「방을 못 찾았어요」
  GET  /ws/CODE          웹소켓 -> 그 방 프로세스로 중계 (터널은 이 한 포트만 열면 된다)

표준 라이브러리만 쓴다. 서버가 꺼지면 방은 되살리지 않는다.
"""
import asyncio, json, os, random, re, signal, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 방 프로세스를 띄우는 명령 줄. 형식은 이 한 곳에만 둔다 ({port}가 방 포트로 바뀐다).
# 환경변수 HANJANG_ROOM_CMD로 바꿀 수 있다(시험은 가짜 방을 쓴다).
ROOM_CMD = os.environ.get(
    "HANJANG_ROOM_CMD",
    "engine/Godot.app/Contents/MacOS/Godot --headless --path game -- --host --dedicated --port={port}",
)
MAX_ROOMS = int(os.environ.get("HANJANG_MAX_ROOMS", "6"))
IDLE_SECONDS = float(os.environ.get("HANJANG_IDLE_SECONDS", "60"))
PORT_BASE = int(os.environ.get("HANJANG_ROOM_PORT_BASE", "7800"))
CAPACITY = 4
NAME_MAX = 12
# 방 프로세스 출력 줄로 방 상태를 안다 (game/net/room.gd)
PLAYING_MARKS = ("START_OK", "GAME_STARTED")
WAITING_MARKS = ("BACK_TO_LOBBY",)

MSG_FULL = "지금은 방이 가득 찼어요"
MSG_NOT_FOUND = "방을 못 찾았어요"
MSG_NAME = "방 이름은 1~12자로 적어 주세요"


class Room:
    def __init__(self, code, name, public, port):
        self.code, self.name, self.public, self.port = code, name, public, port
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
        argv = ROOM_CMD.format(port=room.port).split()
        try:
            room.proc = await asyncio.create_subprocess_exec(
                *argv, cwd=ROOT, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
                stdin=asyncio.subprocess.DEVNULL)
        except OSError:
            del self.rooms[room.code]
            raise
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
    reason = {200: "OK", 201: "Created", 400: "Bad Request", 404: "Not Found", 503: "Service Unavailable"}[status]
    data = json.dumps(body, ensure_ascii=False).encode()
    head = (f"HTTP/1.1 {status} {reason}\r\nContent-Type: application/json; charset=utf-8\r\n"
            f"Content-Length: {len(data)}\r\nAccess-Control-Allow-Origin: *\r\n"
            f"Access-Control-Allow-Headers: content-type\r\nConnection: close\r\n\r\n").encode()
    return head + data


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


async def proxy(room, raw, reader, writer):
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
    try:
        upw.write(raw)
        await asyncio.gather(pipe(reader, upw), pipe(up, writer))
    finally:
        room.players = max(0, room.players - 1)


async def handle(reader, writer):
    try:
        raw, method, path, headers = await read_head(reader)
        if method == "OPTIONS":
            writer.write(reply(200, {}))
        elif m := re.fullmatch(r"/ws/(\d{4})", path):
            room = M.rooms.get(m.group(1))
            if room is None:
                writer.write(reply(404, {"error": MSG_NOT_FOUND}))
            else:
                await proxy(room, raw, reader, writer)
        elif path == "/api/rooms" and method == "GET":
            writer.write(reply(200, [r.info() for r in M.rooms.values() if r.public]))
        elif path == "/api/rooms" and method == "POST":
            body = json.loads(await reader.readexactly(int(headers.get("content-length", "0"))) or b"{}")
            name = str(body.get("name", "")).strip()
            if not 1 <= len(name) <= NAME_MAX:
                writer.write(reply(400, {"error": MSG_NAME}))
            else:
                room = await M.create(name, bool(body.get("public", True)))
                if room is None:
                    writer.write(reply(503, {"error": MSG_FULL}))
                else:
                    base = os.environ.get("HANJANG_PUBLIC_BASE", "http://" + headers.get("host", "localhost"))
                    writer.write(reply(201, {"code": room.code, "name": room.name, "public": room.public,
                                             "path": f"/ws/{room.code}", "link": f"{base}/?room={room.code}"}))
        elif m := re.fullmatch(r"/api/rooms/(\d{4})", path):
            room = M.rooms.get(m.group(1))
            writer.write(reply(200, room.info()) if room else reply(404, {"error": MSG_NOT_FOUND}))
        else:
            writer.write(reply(404, {"error": "없는 주소예요"}))
        await writer.drain()
    except (asyncio.IncompleteReadError, ConnectionError, ValueError, json.JSONDecodeError):
        pass
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
