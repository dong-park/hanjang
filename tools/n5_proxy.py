#!/usr/bin/env python3
"""TCP 중계. 파일 FREEZE 가 생기면 양쪽으로 바이트를 버리되 소켓은 닫지 않는다 - FIN 없이 끊긴 연결(와이파이 끊김, iOS 잠금) 모사.
사용: n5_proxy.py 듣는포트 방장포트 FREEZE파일 로그파일"""
import asyncio, os, sys, time
LP, HP, FREEZE, LOG = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4]
def log(m):
    with open(LOG, "a") as f:
        f.write("%.3f %s\n" % (time.time(), m))
def frozen(start):
    # FREEZE 파일이 생기기 전에 열린 연결만 얼린다. 그 뒤에 새로 연 연결은 정상으로 흐른다.
    return os.path.exists(FREEZE) and start < os.path.getmtime(FREEZE)
async def pipe(r, w, tag, start):
    try:
        while True:
            d = await r.read(65536)
            if not d:
                log("EOF " + tag); break
            if frozen(start):
                continue
            w.write(d); await w.drain()
    except Exception as e:
        log("ERR %s %r" % (tag, e))
    finally:
        if not frozen(start):
            try: w.close()
            except Exception: pass
async def handle(cr, cw):
    log("CONN")
    try:
        sr, sw = await asyncio.open_connection("127.0.0.1", HP)
    except Exception as e:
        log("UPFAIL %r" % e); cw.close(); return
    st = time.time()
    await asyncio.gather(pipe(cr, sw, "c2s", st), pipe(sr, cw, "s2c", st))
async def main():
    s = await asyncio.start_server(handle, "127.0.0.1", LP)
    log("LISTEN %d -> %d" % (LP, HP))
    async with s: await s.serve_forever()
asyncio.run(main())
