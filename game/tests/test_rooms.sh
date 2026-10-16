#!/bin/bash
# n6 방 고르기 화면 시험. 관리 서비스(진짜 헤드리스 방)를 띄우고 test_rooms.gd 를 돌린다. 헤드리스 잠금을 잡고 하나씩 돈다.
# 사용: tests/test_rooms.sh [캡처폴더]
cd "$(dirname "$0")/../.." || exit 1
export PORT=${PORT:-8071}
export SHOT="${1:-}"
[ -n "$SHOT" ] && mkdir -p "$SHOT"
exec python3 game/tests/headless_lock.py 90 bash -c '
HANJANG_ROOM_PORT_BASE=7900 python3 relay/manager.py $PORT >/tmp/hanjang-rooms-mgr.log 2>&1 & MGR=$!
trap "kill $MGR 2>/dev/null; wait $MGR 2>/dev/null" EXIT
sleep 1
curl -s -XPOST localhost:$PORT/api/rooms -d "{\"name\":\"공개방\",\"public\":true}" >/dev/null
PRIV=$(curl -s -XPOST localhost:$PORT/api/rooms -d "{\"name\":\"비밀방\",\"public\":false}" | python3 -c "import sys,json;print(json.load(sys.stdin)[\"code\"])")
sleep 3
engine/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/test_rooms.gd -- --relay=http://127.0.0.1:$PORT --private=$PRIV --shot=$SHOT
'
