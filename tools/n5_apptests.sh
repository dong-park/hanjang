#!/bin/sh
# 기존 앱 헤드리스 시험을 차례로 돌려 종료 코드를 적는다. 사용: tools/n5_apptests.sh 로그파일
cd "$(dirname "$0")/.." || exit 1
LOG=${1:-/dev/stdout}
G=engine/Godot.app/Contents/MacOS/Godot
: > "$LOG"
for t in test_rules test_session_edge test_table test_touch test_fx; do
  $G --headless --path game --script res://tests/$t.gd > /tmp/n5_$t.out 2>&1
  echo "$t exit=$?" >> "$LOG"
done
for t in test_lobby test_net_game test_rejoin; do
  sh game/tests/$t.sh > /tmp/n5_$t.out 2>&1
  echo "$t exit=$?" >> "$LOG"
done
