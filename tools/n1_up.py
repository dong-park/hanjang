#!/usr/bin/env python3
"""n1: 방 서버(7777)·웹 서버(8060)·터널 2개를 세션에서 떼어 띄운다. PID와 로그는 /tmp/n1 에 둔다."""
import subprocess, os, re, time
os.makedirs("/tmp/n1", exist_ok=True)
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def up(name, cmd):
    log = open(f"/tmp/n1/{name}.log", "w")
    p = subprocess.Popen(cmd, cwd=root, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True)
    open(f"/tmp/n1/{name}.pid", "w").write(str(p.pid))
    print(name, p.pid)
up("room", ["engine/Godot.app/Contents/MacOS/Godot", "--headless", "--path", "game", "--", "--autoplay", "--keep-open", "--host", "--name=서버", "--port=7777"])
up("web", ["python3", "tools/serve_web.py", "8060"])
up("tun-ws", ["cloudflared", "tunnel", "--no-autoupdate", "--config", "/dev/null", "--url", "http://127.0.0.1:7777"])
up("tun-web", ["cloudflared", "tunnel", "--no-autoupdate", "--config", "/dev/null", "--url", "http://127.0.0.1:8060"])
time.sleep(12)
for n in ("tun-ws", "tun-web"):
    m = re.search(r"https://[a-z0-9-]+\.trycloudflare\.com", open(f"/tmp/n1/{n}.log").read())
    print(n, m.group(0) if m else "NO URL")
