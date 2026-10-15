#!/usr/bin/env python3
"""n5 자동화 시험. 맥(네이티브 Godot) + 휴대폰(Playwright WebKit iPhone 13 가로 에뮬) 섞인 판을 돌리고 근거를 evidence/n5 에 만든다.
사용(반드시 n5_lock.py 로 감싼다):
  n5_scenarios.py full-headless   맥 2(헤드리스) + 폰 2, 한 판 + 다시 하기
  n5_scenarios.py full-windowed   맥 2(창, --shots 캡처) + 폰 2, 한 판
  n5_scenarios.py drop-fin        폰 탭을 강제로 닫음(FIN 있음) -> 방장이 아는 시간과 재접속
  n5_scenarios.py drop-nofin      중계를 얼려 FIN 없이 끊김 -> 방장이 아는 시간과 재접속
"""
import json, os, re, signal, subprocess, sys, threading, time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
G = os.path.join(ROOT, "engine/Godot.app/Contents/MacOS/Godot")
EV = os.path.join(ROOT, "spec/hanjang-web/evidence/n5")
HP, WEB = 7811, 8065
procs = []


def spawn(cmd, log, **kw):
    f = open(log, "w")
    p = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT, cwd=ROOT, **kw)
    procs.append(p)
    return p


def godot(name, log, args, windowed=False):
    cmd = [G] + ([] if windowed else ["--headless"]) + ["--path", "game", "--"] + args
    return spawn(cmd, log)


class Tail(threading.Thread):
    """로그 파일을 계속 읽으며 줄마다 처음 본 시각을 적는다."""
    def __init__(self, path):
        super().__init__(daemon=True)
        self.path, self.lines, self.stop = path, [], False

    def run(self):
        pos = 0
        while not self.stop:
            try:
                with open(self.path, errors="replace") as f:
                    f.seek(pos)
                    chunk = f.read()
                    pos = f.tell()
                now = time.time()
                for ln in chunk.splitlines():
                    self.lines.append((now, ln))
            except FileNotFoundError:
                pass
            time.sleep(0.05)

    def find(self, pat, nth=1):
        n = 0
        for t, ln in list(self.lines):
            if re.search(pat, ln):
                n += 1
                if n == nth:
                    return t
        return None

    def count(self, pat):
        return sum(1 for _, ln in list(self.lines) if re.search(pat, ln))


def wait(fn, timeout, step=0.1):
    t = time.time()
    while time.time() - t < timeout:
        v = fn()
        if v:
            return v
        time.sleep(step)
    return None


def common(extra=()):
    return ["--autoplay", "--keep-open", "--seed=7", "--hj-time=0.6"] + list(extra)


def phone_args(name, face, port, extra=()):
    return ["--join=127.0.0.1", "--name=" + name, "--face=%d" % face, "--port=%d" % port] + common(extra)


def start_web():
    return spawn([sys.executable, "tools/serve_web.py", str(WEB)], "/tmp/n5_web.log")


def start_phones(out, clients, dur):
    cfg = {"url": "http://127.0.0.1:%d/" % WEB, "outdir": out, "durationSec": dur, "shotEvery": 0, "clients": clients}
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.startswith("ctl-") or f in ("STOP", "phones.done"):
            os.remove(os.path.join(out, f))
    cp = os.path.join(out, "phones.json")
    json.dump(cfg, open(cp, "w"), ensure_ascii=False)
    return spawn(["node", "tools/n5_phones.cjs", cp], os.path.join(out, "phones.out"))


def ctl(out, cid, what, content=""):
    open(os.path.join(out, "ctl-%s-%s" % (cid, what)), "w").write(content)


def cleanup():
    for p in procs:
        if p.poll() is None:
            p.terminate()
    time.sleep(1.5)
    for p in procs:
        if p.poll() is None:
            p.kill()
    for p in procs:
        try:
            p.wait(5)
        except Exception:
            pass


def fmt(t0, t):
    return "미관찰" if t is None else "%.1f초" % (t - t0)


def full(windowed):
    tag = "windowed" if windowed else "headless"
    out = os.path.join(EV, "full-" + tag)
    os.makedirs(out, exist_ok=True)
    start_web()
    time.sleep(1)
    macdir = lambda n: os.path.join(out, "mac-" + n)
    hargs = ["--host", "--name=하늘", "--face=0", "--port=%d" % HP, "--try-start=26", "--quit-after=300"] + common(["--turn-time=2"])
    cargs = ["--join=127.0.0.1", "--name=나", "--face=2", "--port=%d" % HP, "--quit-after=300"] + common(["--turn-time=2"])
    if windowed:
        hargs = [a for a in hargs if a != "--keep-open"] + ["--shots=" + macdir("host")]
        cargs = [a for a in cargs if a != "--keep-open"] + ["--shots=" + macdir("guest")]
        os.makedirs(macdir("host"), exist_ok=True); os.makedirs(macdir("guest"), exist_ok=True)
    else:
        hargs += ["--result-pick=replay"]
    hl = os.path.join(out, "host.log")
    host = godot("host", hl, hargs, windowed)
    tail = Tail(hl); tail.start()
    wait(lambda: tail.find(r"^HOST_READY"), 20)
    t0 = time.time()
    godot("guest", os.path.join(out, "mac-guest.log"), cargs, windowed)
    clients = [
        {"id": "phone1", "kind": "webkit", "args": phone_args("폰1", 1, HP, ["--turn-time=2"])},
        {"id": "phone2", "kind": "webkit", "args": phone_args("폰2", 3, HP, ["--turn-time=2"])},
    ]
    ph = start_phones(out, clients, 280)
    res = {"scenario": "full-" + tag}
    seated = wait(lambda: tail.find(r"^SEATED 4"), 40)
    res["seated4_after"] = fmt(t0, seated)
    if seated:
        time.sleep(1.5)
        for c in ("phone1", "phone2"):
            ctl(out, c, "shot", "1-lobby-%s" % c)
    st = wait(lambda: tail.find(r"^START_OK seats=4"), 40)
    res["start_ok"] = fmt(t0, st)
    if st:
        time.sleep(7)
        for c in ("phone1", "phone2"):
            ctl(out, c, "shot", "2-playing")
    want = 1 if windowed else 2
    done = wait(lambda: tail.count(r"^RESULT ") >= want or None, 240)
    res["result_count_host"] = tail.count(r"^RESULT ")
    time.sleep(2.5)
    for c in ("phone1", "phone2"):
        ctl(out, c, "shot", "3-result-%d" % res["result_count_host"])
    if not windowed:
        res["replay_seen"] = tail.count(r"^REPLAY seats=4")
        res["leaks_host"] = tail.count(r"^LEAK")
    time.sleep(1.5)
    open(os.path.join(out, "STOP"), "w").write("1")
    time.sleep(2)
    res["host_lines"] = {k: tail.count(k) for k in [r"^SEATED", r"^START_OK", r"^REPLAY", r"^RESULT ", r"^PEER_LEFT", r"^LEAK", r"ERROR"]}
    for n in ["guest"]:
        txt = open(os.path.join(out, "mac-guest.log"), errors="replace").read()
        res["guest_leaks"] = txt.count("\nLEAK") + (1 if txt.startswith("LEAK") else 0)
        res["guest_results"] = txt.count("\nRESULT ")
    for c in ("phone1", "phone2"):
        p = os.path.join(out, "console-%s.log" % c)
        txt = open(p, errors="replace").read() if os.path.exists(p) else ""
        res[c] = {"RESULT": txt.count(" RESULT "), "LEAK": txt.count(" LEAK "), "SCREEN_table_net": txt.count("SCREEN table_net"), "error": len(re.findall(r" error ", txt)), "PAGEERROR": txt.count("PAGEERROR")}
    tail.stop = True
    json.dump(res, open(os.path.join(out, "summary.json"), "w"), ensure_ascii=False, indent=1)
    print(json.dumps(res, ensure_ascii=False, indent=1))


def drop(mode):
    out = os.path.join(EV, mode)
    os.makedirs(out, exist_ok=True)
    PP = 7790
    freeze = os.path.join(out, "FREEZE")
    for f in (freeze,):
        if os.path.exists(f): os.remove(f)
    start_web()
    spawn([sys.executable, "tools/n5_proxy.py", str(PP), str(HP), freeze, os.path.join(out, "proxy.log")], "/tmp/n5_proxy.out")
    time.sleep(1)
    hl = os.path.join(out, "host.log")
    host = godot("host", hl, ["--host", "--name=하늘", "--port=%d" % HP, "--try-start=22", "--quit-after=400"] + common(["--turn-time=6", "--auto-delay=1.0"]))
    tail = Tail(hl); tail.start()
    wait(lambda: tail.find(r"^HOST_READY"), 20)
    t00 = time.time()
    godot("guest", os.path.join(out, "mac-guest.log"), ["--join=127.0.0.1", "--name=나", "--port=%d" % HP, "--quit-after=400"] + common(["--turn-time=6", "--auto-delay=1.0"]))
    clients = [{"id": "phone2", "kind": "webkit", "args": phone_args("폰2", 3, PP, ["--turn-time=6", "--auto-delay=1.0"])}]
    start_phones(out, clients, 420)
    res = {"scenario": mode}
    wait(lambda: tail.find(r"^SEATED 3"), 40)
    st = wait(lambda: tail.find(r"^START_OK seats=3"), 40)
    res["started"] = bool(st)
    time.sleep(9)
    ctl(out, "phone2", "shot", "1-before-drop")
    time.sleep(0.6)
    T0 = time.time()
    if mode == "drop-fin":
        ctl(out, "phone2", "close")
    else:
        open(freeze, "w").write("1")
    res["drop_cmd"] = "탭 강제 닫기(브라우저가 소켓 FIN을 보냄)" if mode == "drop-fin" else "중계가 폰2 연결의 바이트를 버리고 소켓은 열어 둠(FIN/RST 없음)"
    probes = []
    cap = 60 if mode == "drop-fin" else 240
    n = 0
    web_reject_shot = False
    while time.time() - T0 < cap:
        left = tail.find(r"^PEER_LEFT_IN_GAME")
        if left:
            break
        if tail.find(r"^RESULT "):
            res["note"] = "방장이 끊김을 알기 전에 판이 끝남"
            break
        n += 1
        pl = os.path.join(out, "probe%d.log" % n)
        ts = time.time()
        p = godot("probe", pl, ["--join=127.0.0.1", "--name=폰2", "--port=%d" % HP, "--quit-after=3.5", "--keep-open"])
        if mode == "drop-nofin" and not web_reject_shot and time.time() - T0 > 5:
            ctl(out, "phone2", "open"); web_reject_shot = True
            time.sleep(7)
            ctl(out, "phone2", "shot", "2-web-retry-rejected")
        p.wait(timeout=20)
        txt = open(pl, errors="replace").read()
        verdict = "거절:게임 중" if "지금 게임 중이에요" in txt else ("재접속 성공" if "REJOINED_OK" in txt else "기타")
        probes.append({"at_s": round(ts - T0, 1), "verdict": verdict})
        if verdict == "재접속 성공":
            break
        time.sleep(4 if mode == "drop-nofin" else 0.3)
    left = tail.find(r"^PEER_LEFT_IN_GAME")
    res["T0_to_PEER_LEFT_IN_GAME"] = fmt(T0, left)
    res["probes"] = probes
    res["host_saw_REJOINED_by_probe"] = tail.count(r"^REJOINED ")
    # 웹 폰이 다시 들어온다 (프로브가 자리를 안 가져갔을 때만 의미)
    if left and not tail.find(r"^REJOINED "):
        time.sleep(1.5)
        ctl(out, "phone2", "open")
        ok = wait(lambda: tail.find(r"^REJOINED ") or None, 30)
        res["web_phone_rejoin_after"] = fmt(T0, ok)
        time.sleep(4)
        ctl(out, "phone2", "shot", "3-web-rejoined")
        # (b) 재접속 뒤 몇 초의 로그 순서
    time.sleep(3)
    open(os.path.join(out, "STOP"), "w").write("1")
    time.sleep(2)
    res["host_lines"] = {k: tail.count(k) for k in [r"^PEER_LEFT_IN_GAME", r"^REJOINED ", r"^PLAYER_REJOINED", r"^REJECT", r"^RESULT ", r"ERROR"]}
    tail.stop = True
    json.dump(res, open(os.path.join(out, "summary.json"), "w"), ensure_ascii=False, indent=1)
    print(json.dumps(res, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *a: sys.exit(1))
    try:
        m = sys.argv[1]
        if m == "full-headless": full(False)
        elif m == "full-windowed": full(True)
        elif m in ("drop-fin", "drop-nofin"): drop(m)
    finally:
        cleanup()
