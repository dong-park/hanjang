#!/bin/sh
# 전용 방 시험: 방 프로세스(--dedicated)는 자리가 없다. 접속자 4명(첫 접속자가 방 주인)이 한 판을 끝내고, 방 주인의 다시 하기로 2판째까지 돈다.
# 판 2: 방 주인이 아닌 접속자의 시작 요청은 무시되고, 2명으로도 시작된다. 판 3: 모두 나가면 방이 비워진다.
# 포트: 첫 인자 또는 NET_TEST_PORT (기본 7810). 헤드리스 Godot는 /tmp/hanjang-headless.lock 을 잡고 하나씩 돌린다.
cd "$(dirname "$0")/../.." || exit 1
# 잠금과 시간 제한(150초) 안에서 자기 자신을 다시 실행한다. 끝나면 남은 Godot는 모두 정리된다.
if [ -z "$HJ_LOCKED" ]; then HJ_LOCKED=1 exec python3 game/tests/headless_lock.py 150 sh "game/tests/test_dedicated.sh" "$@"; fi
GODOT=engine/Godot.app/Contents/MacOS/Godot
P0=${1:-${NET_TEST_PORT:-7810}}
P=$P0
L=$(mktemp -d)
fail=0
run() { n=$1; shift; $GODOT --headless --path game -- --port=$P --seed=7 --turn-time=1 --hj-time=0.6 --quit-after=${QUIT:-30} "$@" > "$L/$n.log" 2>&1 & }
chk() { if ! grep -q -- "$2" "$L/$1.log"; then echo "FAIL: $1 에 '$2' 없음"; fail=1; fi; }
waitlog() { i=0; while ! grep -q -- "$2" "$L/$1.log" 2>/dev/null; do i=$((i+1)); [ $i -gt 50 ] && { echo "FAIL: $1 에 '$2' 가 10초 안에 안 나옴"; fail=1; return 1; }; sleep 0.2; done; }

echo "== 판 1: 방 프로세스 + 접속자 4명, 방 주인이 시작, 다시 하기 =="
run srv --dedicated --code=ABCD --room-name=시험방 --public=0
waitlog srv "^HOST_READY dedicated"
run a --join=127.0.0.1 --name=하늘 --autoplay --keep-open --try-start=4 --result-pick=replay
waitlog srv "^SEATED 1"
run b --join=127.0.0.1 --name=나 --autoplay --keep-open
waitlog srv "^SEATED 2"
run c --join=127.0.0.1 --name=민트 --autoplay --keep-open --cheat
waitlog srv "^SEATED 3"
run d --join=127.0.0.1 --name=체리 --autoplay --keep-open
waitlog srv "^SEATED 4"
wait
chk srv "^START_OK seats=4"
chk srv "^RESULT_SERVER"
chk srv "^REPLAY seats=4"
for n in a b c d; do chk $n "^RESULT "; done
if grep -q "^SEATED.*서버" "$L/srv.log"; then echo "FAIL: 방 프로세스가 자리를 차지함"; fail=1; fi
for n in a b c d; do
  if grep -q "^LEAK" "$L/$n.log"; then echo "FAIL: $n LEAK"; fail=1; fi
done
# 판마다 접속자의 MYHAND 자리는 하나다 (두 판이라 자리 번호는 같은 값이 유지된다)
for n in a b c d; do
  S=$(grep "^MYHAND" "$L/$n.log" | awk '{print $2}' | sort -u | wc -l)
  [ "$S" -eq 1 ] || { echo "FAIL: $n 로그에 여러 자리 패"; fail=1; }
done
SEATS=$(for n in a b c d; do grep "^MYHAND" "$L/$n.log" | awk '{print $2}' | sort -u; done | sort -u | wc -l)
[ "$SEATS" -eq 4 ] || { echo "FAIL: 접속자 자리가 4개가 아님($SEATS)"; fail=1; }
R=$(for n in a b c d; do grep "^RESULT " "$L/$n.log" | head -1; done | sort -u | wc -l)
[ "$R" -eq 1 ] || { echo "FAIL: 첫 판 등수가 접속자마다 다름"; fail=1; }
grep "^RESULT " "$L/a.log" | head -1 | sed "s/^/  a /"

echo "== 판 2: 방 주인이 아닌 접속자의 시작 요청은 무시, 2명으로 시작 =="
P=$((P0+1))
run s2 --dedicated --code=EFGH --public=1
waitlog s2 "^HOST_READY dedicated"
run p --join=127.0.0.1 --name=하늘 --autoplay --try-start=4
waitlog s2 "^SEATED 1"
run q --join=127.0.0.1 --name=나 --autoplay --try-start=1.5
waitlog s2 "^SEATED 2"
wait
chk s2 "^ASK_IGNORED start"
chk s2 "^START_OK seats=2"
chk s2 "^RESULT_SERVER"
chk p "^RESULT "
chk q "^RESULT "

echo "== 판 3: 판 중 모두 나가면 방이 비워진다 =="
P=$((P0+2))
run s3 --dedicated --code=IJKL
waitlog s3 "^HOST_READY dedicated"
run u --join=127.0.0.1 --name=하늘 --try-start=2 --leave-after=4.5
waitlog s3 "^SEATED 1"
run v --join=127.0.0.1 --name=나 --leave-after=4.5
wait
chk s3 "^START_OK seats=2"
chk s3 "^ROOM_EMPTY"
chk s3 "^SESSION_RESET"

[ $fail = 0 ] && echo "NET_DEDICATED_TEST_PASS" && exit 0
echo "NET_DEDICATED_TEST_FAIL (logs: $L)"; exit 1
