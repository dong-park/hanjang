#!/usr/bin/env python3
"""헤드리스 시험을 하나씩 돌리려고 /tmp/hanjang-headless.lock 을 잡고 명령을 실행한다. 사용: n5_lock.py 명령 [인자...]"""
import fcntl, subprocess, sys, time
f = open("/tmp/hanjang-headless.lock", "w")
t = time.time()
fcntl.flock(f, fcntl.LOCK_EX)
print("lock wait %.1fs" % (time.time() - t), flush=True)
sys.exit(subprocess.call(sys.argv[1:]))
