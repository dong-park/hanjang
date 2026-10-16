#!/usr/bin/env python3
"""시험용 가짜 방 프로세스. 포트를 열고 받은 줄을 되돌려 준다. 'start' 줄이면 START_OK, 'back'이면 BACK_TO_LOBBY를 출력한다."""
import socketserver, sys


class H(socketserver.StreamRequestHandler):
    def handle(self):
        for line in self.rfile:
            self.wfile.write(line)
            if line.strip() == b"start":
                print("START_OK seats=2", flush=True)
            if line.strip() == b"back":
                print("BACK_TO_LOBBY seats=2", flush=True)


class S(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


print("HOST_READY", flush=True)
S(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
