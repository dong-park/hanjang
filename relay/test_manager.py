import json, os, socket, subprocess, sys, tempfile, time, unittest, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = 18070


def api(method, path, body=None, ip=None):
    req = urllib.request.Request(f"http://127.0.0.1:{PORT}{path}", method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"CF-Connecting-IP": ip} if ip else {})
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


class Conn:
    def __init__(self, s):
        self.s, self.f = s, s.makefile("rb")

    def sendall(self, b):
        self.s.sendall(b)

    def close(self):
        self.f.close()
        self.s.close()


def ws_connect(code, ip=None):
    s = socket.create_connection(("127.0.0.1", PORT), timeout=5)
    extra = f"CF-Connecting-IP: {ip}\r\n" if ip else ""
    s.sendall(f"GET /ws/{code} HTTP/1.1\r\nHost: x\r\n{extra}Upgrade: websocket\r\nConnection: Upgrade\r\n\r\n".encode())
    s = Conn(s)
    assert s.f.readline().startswith(b"GET /ws/")  # 가짜 방이 첫 줄(요청 줄)을 되돌린다 = 중계됨
    return s


def echo(s, line):
    s.sendall(line + b"\n")
    while True:
        got = s.f.readline()
        if got == line + b"\n":
            return got


def wait_for(cond, secs=6):
    end = time.time() + secs
    while time.time() < end:
        if cond():
            return True
        time.sleep(0.2)
    return False


def listed():
    return {x["code"]: x for x in api("GET", "/api/rooms")[1]}


class ManagerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.log = os.path.join(tempfile.mkdtemp(), "manager.log")
        env = dict(os.environ, HANJANG_LOG=cls.log, HANJANG_ROOM_CMD=f"{sys.executable} {HERE}/fake_room.py {{port}}",
                   HANJANG_MAX_ROOMS="3", HANJANG_IDLE_SECONDS="2", HANJANG_ROOM_PORT_BASE="18100")
        cls.p = subprocess.Popen([sys.executable, f"{HERE}/manager.py", str(PORT)], env=env, stdout=subprocess.PIPE)
        cls.p.stdout.readline()

    @classmethod
    def tearDownClass(cls):
        cls.p.terminate()
        cls.p.wait()

    def test_1_create_link_and_ws_reach_same_room(self):
        st, r = api("POST", "/api/rooms", {"name": "열두글자방이름입니다요", "public": True})
        self.assertEqual(st, 201)
        self.assertRegex(r["code"], r"^\d{4}$")
        self.assertTrue(r["link"].endswith("/?room=" + r["code"]))
        self.assertEqual(r["path"], "/ws/" + r["code"])
        s = ws_connect(r["code"])
        self.assertEqual(echo(s, b"hi"), b"hi\n")
        s.close()

    def test_5_cloudflare_h2_head_gets_upgrade_lines(self):
        # 터널(HTTP/2)에서 실제로 캡처한 머리: Upgrade 줄이 없고 Connection은 keep-alive다
        _, r = api("POST", "/api/rooms", {"name": "h2", "public": True})
        head = (f"GET /ws/{r['code']} HTTP/1.1\r\nHost: a.trycloudflare.com\r\nAccept-Encoding: gzip\r\n"
                "Cdn-Loop: cloudflare; loops=1; subreqs=1\r\nCf-Connecting-Ip: 1.2.3.4\r\nConnection: keep-alive\r\n"
                "Sec-Websocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-Websocket-Version: 13\r\nX-Forwarded-Proto: https\r\n\r\n")
        s = socket.create_connection(("127.0.0.1", PORT), timeout=5)
        s.sendall(head.encode())
        f = s.makefile("rb")
        got = []
        while (ln := f.readline()) not in (b"\r\n", b""):
            got.append(ln.strip().lower())
        self.assertIn(b"upgrade: websocket", got)
        self.assertIn(b"connection: upgrade", got)
        self.assertNotIn(b"connection: keep-alive", got)
        s.close()

    def test_2_name_limit(self):
        st, r = api("POST", "/api/rooms", {"name": "열세글자를넘는방이름입니다", "public": True})
        self.assertEqual(st, 400)
        st, _ = api("POST", "/api/rooms", {"name": "", "public": True})
        self.assertEqual(st, 400)

    def test_3_list_public_only_and_playing_not_joinable(self):
        self.assertTrue(wait_for(lambda: not listed(), 10))
        _, a = api("POST", "/api/rooms", {"name": "A방", "public": True})
        _, b = api("POST", "/api/rooms", {"name": "B방", "public": True})
        _, c = api("POST", "/api/rooms", {"name": "비밀", "public": False})
        sa, sb, sc = ws_connect(a["code"]), ws_connect(b["code"]), ws_connect(c["code"])
        echo(sb, b"start")
        self.assertTrue(wait_for(lambda: listed().get(b["code"], {}).get("state") == "playing"))
        rooms = listed()
        self.assertNotIn(c["code"], rooms)
        self.assertEqual((rooms[a["code"]]["state"], rooms[a["code"]]["players"], rooms[a["code"]]["joinable"]), ("waiting", 1, True))
        self.assertEqual((rooms[b["code"]]["state"], rooms[b["code"]]["joinable"]), ("playing", False))
        st, r = api("GET", "/api/rooms/" + c["code"])
        self.assertEqual((st, r["name"]), (200, "비밀"))
        st, r = api("GET", "/api/rooms/0000" if c["code"] != "0000" else "/api/rooms/0001")
        self.assertEqual((st, r["error"]), (404, "방을 못 찾았어요"))
        echo(sb, b"back")
        self.assertTrue(wait_for(lambda: listed()[b["code"]]["joinable"]))
        for s in (sa, sb, sc):
            s.close()

    def test_4_limit_and_idle_cleanup(self):
        self.assertTrue(wait_for(lambda: not listed(), 10))
        made = [api("POST", "/api/rooms", {"name": f"방{i}", "public": True}) for i in range(3)]
        self.assertTrue(all(st == 201 for st, _ in made))
        st, r = api("POST", "/api/rooms", {"name": "넷째", "public": True})
        self.assertEqual((st, r["error"]), (503, "지금은 방이 가득 찼어요"))
        self.assertEqual(len(listed()), 3)
        self.assertTrue(wait_for(lambda: not listed(), 10))
        self.assertEqual(api("GET", "/api/rooms/" + made[0][1]["code"])[0], 404)
        self.assertEqual(api("POST", "/api/rooms", {"name": "다시", "public": True})[0], 201)

    def test_5_name_rules(self):
        for name, want in (("", "이름을 적어 주세요"), ("열세글자를넘는방이름입니다", "방 이름은 1~12자로 적어 주세요"),
                           ("곰방🙂", "이모지는 쓸 수 없어요"), ("시발방", "쓸 수 없는 말이 들어 있어요")):
            st, r = api("POST", "/api/rooms", {"name": name, "public": True})
            self.assertEqual((st, r["error"]), (400, want), name)
        self.assertTrue(wait_for(lambda: not listed(), 10))

    def test_6_flood_blocks_only_that_address(self):
        self.assertTrue(wait_for(lambda: not listed(), 10))
        st, room = api("POST", "/api/rooms", {"name": "폭주시험", "public": True}, ip="8.8.4.4")
        self.assertEqual(st, 201)
        self.assertTrue(len(room["secret"]) >= 8)
        self.assertEqual(api("GET", "/api/rooms/" + room["code"])[1]["secret"], room["secret"])
        self.assertNotIn("secret", listed()[room["code"]])
        codes = [api("GET", "/api/rooms", ip="9.9.9.9")[0] for _ in range(40)]
        self.assertIn(429, codes)
        self.assertEqual(api("GET", "/api/rooms", ip="9.9.9.9")[0], 429)
        s = ws_connect(room["code"], ip="8.8.4.4")  # 다른 주소의 방 접속은 그대로 돈다
        self.assertEqual(echo(s, b"hi"), b"hi\n")
        s.close()
        self.assertIsNone(self.p.poll())  # 서버 프로세스는 살아 있다

    def test_7_log_has_no_names_or_full_ips(self):
        api("POST", "/api/rooms", {"name": "비밀이름방", "public": True}, ip="123.45.67.89")
        s = ws_connect(next(iter(listed())), ip="123.45.67.89")
        s.close()
        time.sleep(0.5)
        text = open(self.log, encoding="utf-8").read()
        self.assertIn("123.45.x.x", text)
        self.assertIn("ROOM_OPEN", text)
        for bad in ("비밀이름방", "123.45.67.89", "폭주시험", "9.9.9.9"):
            self.assertNotIn(bad, text)


if __name__ == "__main__":
    unittest.main()
