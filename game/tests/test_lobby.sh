#!/bin/sh
# 대기실 헤드리스 시험: 방장+3명 참가, 5번째 거절, 시작, 게임 중 거절, 방장 나감 -> 첫 화면.
cd "$(dirname "$0")/../.." || exit 1
GODOT=engine/Godot.app/Contents/MacOS/Godot
P=7793
L=$(mktemp -d)
run() { n=$1; shift; $GODOT --headless --path game -- --port=$P "$@" > "$L/$n.log" 2>&1 & }
run host --host --name=하늘 --face=2 --try-start=1,4.5 --leave-after=7
sleep 1.5
run a --join=127.0.0.1 --name=나 --face=0 --quit-after=9
run b --join=127.0.0.1 --name=민트 --face=1 --quit-after=9
run c --join=127.0.0.1 --name=체리 --face=3 --quit-after=9
sleep 1.5
run e --join=127.0.0.1 --name=다섯 --quit-after=9
sleep 2
run f --join=127.0.0.1 --name=여섯 --quit-after=9
wait
cat "$L"/*.log | grep -E "^(HOST_READY|SEATED|REJECT|JOIN_FAILED|START|GAME_STARTED|LEFT_TO_TITLE|SCREEN)" | sort | uniq -c
fail=0
chk() { if ! grep -q "$2" "$L/$1.log"; then echo "FAIL: $1 $2"; fail=1; fi; }
chk host "START_BLOCKED seats=1"
chk host "SEATED 4 "
chk host "REJECT .* 방이 꽉 찼어요"
chk host "START_OK seats=4"
chk host "REJECT .* 지금 게임 중이에요"
chk e "JOIN_FAILED 방이 꽉 찼어요"
chk f "JOIN_FAILED 지금 게임 중이에요"
for n in e f; do chk $n "SCREEN join"; if grep -q "SCREEN lobby" "$L/$n.log"; then echo "FAIL: $n entered lobby"; fail=1; fi; done
for n in a b c; do chk $n "GAME_STARTED 4"; chk $n "LEFT_TO_TITLE 방장이 나갔어요"; chk $n "SCREEN title"; done
[ $fail = 0 ] && echo "LOBBY_TEST_PASS" && exit 0
echo LOBBY_TEST_FAIL; exit 1
