#!/bin/sh
# 세션 헤드리스 시험: 방장+3명이 --autoplay --seed=7로 한 판을 끝내고, 등수 일치·패 비공개·--cheat 무시·시간 초과 자동 뽑기를 본다.
# 두 번째 판은 3명 중 한 명이 판 중에 나가도 남은 둘이 끝까지 하는지 본다.
cd "$(dirname "$0")/../.." || exit 1
GODOT=engine/Godot.app/Contents/MacOS/Godot
P=7794
L=$(mktemp -d)
fail=0
run() { n=$1; shift; $GODOT --headless --path game -- --port=$P --autoplay --seed=7 --turn-time=1 --hj-time=0.6 --quit-after=90 "$@" > "$L/$n.log" 2>&1 & }
chk() { if ! grep -q -- "$2" "$L/$1.log"; then echo "FAIL: $1 에 '$2' 없음"; fail=1; fi; }

echo "== 판 1: 방장+3명 =="
run host --host --name=하늘 --try-start=2.5
sleep 1
run a --join=127.0.0.1 --name=나
run b --join=127.0.0.1 --name=민트
run c --join=127.0.0.1 --name=체리 --cheat
wait
for n in host a b c; do
  chk $n "^RESULT "
  grep "^RESULT " "$L/$n.log" | head -1 | sed "s/^/  $n /"
done
R=$(for n in host a b c; do grep "^RESULT " "$L/$n.log" | head -1; done | sort -u | wc -l)
[ "$R" -eq 1 ] || { echo "FAIL: 네 로그의 등수가 다름"; fail=1; }
# 접속자 로그에 남의 패가 없다: 새어 나온 카드 없음, MYHAND 는 자기 자리만
for n in a b c; do
  if grep -q "^LEAK" "$L/$n.log"; then echo "FAIL: $n LEAK"; fail=1; fi
  S=$(grep "^MYHAND" "$L/$n.log" | awk '{print $2}' | sort -u | wc -l)
  [ "$S" -eq 1 ] || { echo "FAIL: $n 로그에 여러 자리 패"; fail=1; }
done
# --cheat 요청마다 방장 로그에 무시 기록
NC=$(grep -c "^CHEAT_SENT" "$L/c.log")
[ "$NC" -gt 0 ] || { echo "FAIL: cheat 요청이 한 번도 안 나감"; fail=1; }
grep "^CHEAT_SENT" "$L/c.log" | while read -r _ seat rid kind; do
  grep -q "^IGNORED $seat $rid $kind" "$L/host.log" || echo "MISSING $seat $rid $kind"
done > "$L/missing.txt"
if [ -s "$L/missing.txt" ]; then echo "FAIL: 무시 기록 빠짐"; head -3 "$L/missing.txt"; fail=1; fi
echo "  cheat 요청 $NC 건, 무시 기록 일치"
chk host "^AUTO_DRAW"
echo "  AUTO_DRAW $(grep -c '^AUTO_DRAW' "$L/host.log") 건, AUTO_COLOR $(grep -c '^AUTO_COLOR' "$L/host.log") 건"

echo "== 판 2: 3명 중 한 명이 판 중에 나감 =="
P=7795
run h2 --host --name=하늘 --try-start=2.5
sleep 1
run x --join=127.0.0.1 --name=나
run y --join=127.0.0.1 --name=민트 --leave-after=4.2
wait
chk h2 "^PLAYER_LEFT"
chk x "^PLAYER_LEFT"
chk h2 "^RESULT "
chk x "^RESULT "
grep "^RESULT " "$L/h2.log" | head -1 | sed "s/^/  h2 /"
[ "$(for n in h2 x; do grep "^RESULT " "$L/$n.log" | head -1; done | sort -u | wc -l)" -eq 1 ] || { echo "FAIL: 판 2 등수 다름"; fail=1; }

[ $fail = 0 ] && echo "NET_GAME_TEST_PASS" && exit 0
echo "NET_GAME_TEST_FAIL (logs: $L)"; exit 1
