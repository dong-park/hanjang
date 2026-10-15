#!/bin/sh
# 재접속 헤드리스 시험: 판 중에 나간 사람이 같은 닉네임으로 돌아와 자리를 되찾고 끝까지 한다. 다른 닉네임은 계속 "게임 중"으로 거절한다.
cd "$(dirname "$0")/../.." || exit 1
GODOT=engine/Godot.app/Contents/MacOS/Godot
P=${1:-7797}
L=$(mktemp -d)
fail=0
run() { n=$1; shift; $GODOT --headless --path game -- --port=$P --autoplay --seed=7 --turn-time=2 --hj-time=0.6 --quit-after=60 "$@" > "$L/$n.log" 2>&1 & }
chk() { if ! grep -q -- "$2" "$L/$1.log"; then echo "FAIL: $1 에 '$2' 없음"; fail=1; fi; }
seated() { i=0; while ! grep -q "^SEATED $1" "$L/host.log" 2>/dev/null; do i=$((i+1)); [ $i -gt 50 ] && break; sleep 0.1; done; }
run host --host --name=하늘 --try-start=2.5
i=0; while ! grep -q "^HOST_READY" "$L/host.log" 2>/dev/null; do i=$((i+1)); [ $i -gt 50 ] && break; sleep 0.2; done
run x --join=127.0.0.1 --name=나
seated "2 나"
run y --join=127.0.0.1 --name=민트 --leave-after=4.2
seated "3 민트"
run dup --join=127.0.0.1 --name=나 --quit-after=4
sleep 5.5
run y2 --join=127.0.0.1 --name=민트
run z --join=127.0.0.1 --name=낯선이 --quit-after=9
wait
chk host "^PLAYER_LEFT"
chk host "^REJOINED .* seat=2 민트"
chk host "^PLAYER_REJOINED seat=2"
chk y2 "^REJOINED_OK"
chk y2 "^MYHAND seat=2"
chk z "JOIN_FAILED 지금 게임 중이에요"
chk dup "JOIN_FAILED 같은 닉네임이 있어요"
chk host "^RESULT "
chk y2 "^RESULT "
grep -q "^LEAK" "$L/y2.log" && { echo "FAIL: y2 LEAK"; fail=1; }
[ $fail = 0 ] && echo "REJOIN_TEST_PASS" && exit 0
echo "REJOIN_TEST_FAIL (logs: $L)"; exit 1
