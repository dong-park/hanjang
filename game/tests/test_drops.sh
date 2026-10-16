#!/bin/sh
# 끊김 시험 (n5).
# 판 1 (T13): 접속자 한 명의 프로세스를 SIGSTOP 으로 얼린다(FIN도 응답도 없는 끊김). 서버가 20초 안에 알고(DROP_DETECTED 시각),
#             나머지 화면에 PLAYER_LEFT(끊김 문구)가 온다.
# 판 2 (T12): 방 주인이 나갔다 --owner-grace 안에 돌아오면 주인 자리가 그대로고, 안 돌아오면 다음 사람에게 넘어가며 판이 이어진다.
# 판 3 (T12): 기본 대기 30초: 안 돌아오면 30초쯤 뒤에 넘어간다.
# 포트: 첫 인자 또는 NET_TEST_PORT (기본 7830). 헤드리스 Godot는 /tmp/hanjang-headless.lock 을 잡고 하나씩 돌린다.
cd "$(dirname "$0")/../.." || exit 1
if [ -z "$HJ_LOCKED" ]; then HJ_LOCKED=1 exec python3 game/tests/headless_lock.py ${HJ_LIMIT:-420} sh "game/tests/test_drops.sh" "$@"; fi
GODOT=engine/Godot.app/Contents/MacOS/Godot
P0=${1:-${NET_TEST_PORT:-7830}}
P=$P0
L=$(mktemp -d)
fail=0
PIDS=""
run() { n=$1; shift; $GODOT --headless --path game -- --port=$P --seed=7 --turn-time=${TT:-4} --hj-time=0.6 --quit-after=${QUIT:-30} --token-file=$L/tok_$n "$@" > "$L/$n.log" 2>&1 & PIDS="$PIDS $!"; LAST=$!; }
chk() { if ! grep -q -- "$2" "$L/$1.log"; then echo "FAIL: $1 에 '$2' 없음"; fail=1; fi; }
nochk() { if grep -q -- "$2" "$L/$1.log"; then echo "FAIL: $1 에 '$2' 가 있으면 안 됨"; fail=1; fi; }
waitlog() { i=0; while ! grep -q -- "$2" "$L/$1.log" 2>/dev/null; do i=$((i+1)); [ $i -gt ${3:-75} ] && { echo "FAIL: $1 에 '$2' 가 안 나옴"; fail=1; return 1; }; sleep 0.2; done; }
now() { python3 -c 'import time;print("%.3f"%time.time())'; }
tval() { grep -m1 -- "$2" "$L/$1.log" | sed 's/.* t=//'; }
stop_all() { for p in $PIDS; do kill -KILL $p 2>/dev/null; done; PIDS=""; }
trap stop_all EXIT

QUIT=45
echo "== 판 1: FIN 없는 끊김을 20초 안에 안다 =="
run srv --dedicated --code=ABCD
waitlog srv "^HOST_READY dedicated"
run a --join=127.0.0.1 --name=하늘 --autoplay --try-start=7
waitlog srv "^SEATED 1"
run b --join=127.0.0.1 --name=구름 --autoplay
waitlog srv "^SEATED 2"
run c --join=127.0.0.1 --name=민트
VICTIM=$LAST
waitlog srv "^SEATED 3"
waitlog srv "^START_OK seats=3"
sleep 2
T0=$(now)
kill -STOP $VICTIM
waitlog srv "^DROP_DETECTED" 125
T1=$(tval srv "^DROP_DETECTED")
chk srv "^PEER_LEFT_IN_GAME"
waitlog a "^PLAYER_LEFT" 50
waitlog b "^PLAYER_LEFT" 50
kill -KILL $VICTIM
if [ -n "$T1" ]; then
  D=$(python3 -c "print('%.1f'%($T1-$T0))")
  echo "  얼린 뒤 서버가 안 시간: ${D}초"
  python3 -c "import sys;sys.exit(0 if 0<$T1-$T0<20 else 1)" || { echo "FAIL: 20초 안에 못 잡음 (${D}초)"; fail=1; }
fi
stop_all

QUIT=60
echo "== 판 2: 주인이 대기 안에 돌아오면 주인 그대로, 안 돌아오면 넘어감 =="
P=$((P0+1))
OWNER_ARGS="--owner-grace=8"
run s2 --dedicated --code=EFGH --owner-grace=8
waitlog s2 "^HOST_READY dedicated"
run o --join=127.0.0.1 --name=하늘 --autoplay --try-start=8 --leave-after=11
waitlog s2 "^SEATED 1"
run p --join=127.0.0.1 --name=구름 --autoplay
waitlog s2 "^SEATED 2"
run q --join=127.0.0.1 --name=민트 --autoplay
waitlog s2 "^SEATED 3"
waitlog s2 "^OWNER_GRACE_START" 100
run o2 --join=127.0.0.1 --name=하늘 --autoplay --token-file=$L/tok_o
waitlog o2 "^REJOINED_OK" 60
sleep 10
chk o2 "^OWNER_IS_ME"
nochk s2 "^OWNER_TRANSFER"
nochk p "^OWNER_CHANGED"
stop_all

P=$((P0+2))
run s3 --dedicated --code=IJKL --owner-grace=4
waitlog s3 "^HOST_READY dedicated"
run o3 --join=127.0.0.1 --name=하늘 --autoplay --try-start=8 --leave-after=11
waitlog s3 "^SEATED 1"
run p3 --join=127.0.0.1 --name=구름 --autoplay
waitlog s3 "^SEATED 2"
run q3 --join=127.0.0.1 --name=민트 --autoplay
waitlog s3 "^SEATED 3"
waitlog s3 "^OWNER_TRANSFER" 150
waitlog p3 "^OWNER_CHANGED 구름" 25
waitlog q3 "^OWNER_CHANGED 구름" 25
chk p3 "^OWNER_IS_ME"
nochk q3 "^OWNER_IS_ME"
sleep 6
N=$(awk '/^OWNER_TRANSFER/{f=1} f' "$L/s3.log" | grep -c "^ACCEPT\|^AUTO_")
[ "$N" -ge 3 ] || { echo "FAIL: 주인이 넘어간 뒤 판이 이어지지 않음($N)"; fail=1; }
if grep -E "하늘|구름|민트" "$L/s2.log" "$L/s3.log" | grep -q .; then echo "FAIL: 방 프로세스 로그에 닉네임"; fail=1; fi
stop_all

QUIT=80
echo "== 판 3: 기본 대기 30초 =="
P=$((P0+3))
run s4 --dedicated --code=MNOP
waitlog s4 "^HOST_READY dedicated"
run o4 --join=127.0.0.1 --name=하늘 --autoplay --try-start=8 --leave-after=11
waitlog s4 "^SEATED 1"
run p4 --join=127.0.0.1 --name=구름 --autoplay
waitlog s4 "^SEATED 2"
run q4 --join=127.0.0.1 --name=민트 --autoplay
waitlog s4 "^OWNER_GRACE_START" 100
waitlog s4 "^OWNER_TRANSFER" 200
G0=$(tval s4 "^OWNER_GRACE_START"); G1=$(tval s4 "^OWNER_TRANSFER")
python3 -c "
d=$G1-$G0
print('  대기 %.1f초' % d)
import sys; sys.exit(0 if 29.5<=d<=32 else 1)" || { echo "FAIL: 기본 대기가 30초가 아님"; fail=1; }
stop_all

[ $fail = 0 ] && echo "NET_DROPS_TEST_PASS" && exit 0
echo "NET_DROPS_TEST_FAIL (logs: $L)"; exit 1
