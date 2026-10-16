import json, os, socket, subprocess, sys, time, unittest, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = 18070


def api(method, path, body=None):
    req = urllib.request.Request(f"http://127.0.0.1:{PORT}{path}", method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def ws_connect(code):
    s = socket.create_connection(("127.0.0.1", PORT), timeout=5)
    s.sendall(f"GET /ws/{code} HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n".encode())
    s.f = s.makefile("rb")
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
        env = dict(os.environ, HANJANG_ROOM_CMD=f"{sys.executable} {HERE}/fake_room.py {{port}}",
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


if __name__ == "__main__":
    unittest.main()
