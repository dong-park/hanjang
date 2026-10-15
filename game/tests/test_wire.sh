#!/bin/sh
# 판 화면 연결 헤드리스 시험(n7): 한 판 끝 -> 결과 화면 -> 다시 하기 / 대기실로, 판 중 나감 -> 연출과 결과.
cd "$(dirname "$0")/../.." || exit 1
GODOT=engine/Godot.app/Contents/MacOS/Godot
L=$(mktemp -d)
fail=0
run() { n=$1; shift; $GODOT --headless --path game -- --autoplay --keep-open --seed=7 --turn-time=1 --hj-time=0.6 "$@" > "$L/$n.log" 2>&1 & }
chk() { if ! grep -q -- "$2" "$L/$1.log"; then echo "FAIL: $1 에 '$2' 없음"; fail=1; fi; }
cnt() { grep -c -- "$2" "$L/$1.log"; }

echo "== 1. 다시 하기: 같은 둘이 바로 다음 판 =="
P=7801
run h1 --port=$P --host --name=하늘 --try-start=1.5 --result-pick=replay --quit-after=75
sleep 1
run a1 --port=$P --join=127.0.0.1 --name=나 --quit-after=75
wait
for n in h1 a1; do
  [ "$(cnt $n '^RESULT_SHOWN')" -ge 2 ] || { echo "FAIL: $n 결과 화면이 두 번 안 뜸"; fail=1; }
  [ "$(cnt $n '^SCREEN table_net')" -ge 2 ] || { echo "FAIL: $n 판 화면이 두 번 안 뜸"; fail=1; }
done
chk h1 "^REPLAY seats=2"
grep -h "^RESULT_SHOWN" "$L/a1.log" | head -1 | sed 's/^/  a1 /'

echo "== 2. 대기실로: 자리 그대로 =="
P=7802
run h2 --port=$P --host --name=하늘 --try-start=1.5 --result-pick=lobby --quit-after=60
sleep 1
run a2 --port=$P --join=127.0.0.1 --name=나 --quit-after=60
wait
for n in h2 a2; do
  chk $n "^BACK_TO_LOBBY seats=2"
  NEXT=$(awk '/^BACK_TO_LOBBY/{f=1} f && /^SCREEN /{print; exit}' "$L/$n.log")
  [ "$NEXT" = "SCREEN lobby" ] || { echo "FAIL: $n 결과 다음 화면이 대기실이 아님: $NEXT"; fail=1; }
done

echo "== 3. 판 중 나감: 연출, 남은 사람끼리 계속, 결과 =="
P=7803
run h3 --port=$P --host --name=하늘 --try-start=1.5 --quit-after=60
sleep 1
run x3 --port=$P --join=127.0.0.1 --name=나 --quit-after=60
run y3 --port=$P --join=127.0.0.1 --name=민트 --leave-after=6
wait
chk h3 "^DISCONNECT_FX seat=2"
chk x3 "^DISCONNECT_FX seat=2"
for n in h3 x3; do chk $n "^RESULT_SHOWN"; done
grep -h "^RESULT_SHOWN" "$L/x3.log" | head -1 | sed 's/^/  x3 /'

[ $fail = 0 ] && echo "WIRE_TEST_PASS" && exit 0
echo "WIRE_TEST_FAIL (logs: $L)"; exit 1
