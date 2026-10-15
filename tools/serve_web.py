#!/usr/bin/env python3
"""build/web 를 같은 와이파이에 http로 준다. 휴대폰이 열 주소를 보인다."""
import http.server, os, socket, subprocess, sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")

if not os.path.isfile(os.path.join(ROOT, "index.html")):
    sys.exit("웹 빌드가 없습니다: build/web/index.html (먼저 tools/export_web.sh)")


def lan_ips():
    ips = []
    for iface in ("en0", "en1", "en2"):
        r = subprocess.run(["ipconfig", "getifaddr", iface], capture_output=True, text=True)
        if r.stdout.strip():
            ips.append(r.stdout.strip())
    if not ips:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("10.255.255.255", 1))
            ips.append(s.getsockname()[0])
        except OSError:
            pass
        finally:
            s.close()
    return ips


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def end_headers(self):
        # no-cache: 매번 재검증해 새 빌드는 바로 받고, 그대로면 304로 39MB wasm을 다시 보내지 않는다.
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


ips = lan_ips()
print("한장! 웹 서버 — 같은 와이파이의 휴대폰 브라우저에서 아래 주소를 여세요")
for ip in ips:
    print(f"  http://{ip}:{PORT}/")
if not ips:
    print("  (와이파이 주소를 못 찾았습니다. 와이파이 연결을 확인하세요)")
print("끄려면 Ctrl+C")
sys.stdout.flush()
http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
