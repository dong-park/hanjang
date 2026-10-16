#!/usr/bin/env python3
"""헤드리스 시험 실행기: /tmp/hanjang-headless.lock 을 잡고(하나씩 차례로) 시간 제한 안에서 명령을 돌린다.
사용: headless_lock.py <제한초> <명령...>  — 제한을 넘기면 자식 프로세스 그룹 전체를 죽이고 124로 끝낸다."""
import fcntl, os, signal, subprocess, sys

limit = float(sys.argv[1])
fd = os.open("/tmp/hanjang-headless.lock", os.O_CREAT | os.O_RDWR, 0o644)
fcntl.flock(fd, fcntl.LOCK_EX)
p = subprocess.Popen(sys.argv[2:], start_new_session=True)
try:
    sys.exit(p.wait(timeout=limit))
except subprocess.TimeoutExpired:
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except PermissionError:
        p.terminate()
    p.wait(timeout=5)
    print("TIMEOUT: %ss 넘겨 강제 종료" % limit)
    sys.exit(124)
finally:
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass
