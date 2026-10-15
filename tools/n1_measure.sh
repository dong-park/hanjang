#!/bin/zsh
# n1: 헤드리스 방 N개를 띄워 시작 시간(HOST_READY까지)과 방당 RSS(MB)를 잰다. 사용: n1_measure.sh N [시작포트]
# /tmp/hanjang-headless.lock 을 잡고 돈다. 끝나면 방을 모두 끈다.
cd "${0:A:h}/.." || exit 1
if [ -z "$N1_LOCKED" ]; then exec env N1_LOCKED=1 python3 tools/n5_lock.py "$0" "$@"; fi
N=${1:-1}; P0=${2:-7790}
GODOT=engine/Godot.app/Contents/MacOS/Godot
L=$(mktemp -d); pids=()
t0=$(python3 -c 'import time;print(time.time())')
for i in $(seq 0 $((N-1))); do
  $GODOT --headless --path game -- --autoplay --keep-open --host --name=방$i --port=$((P0+i)) --quit-after=40 > $L/r$i.log 2>&1 &
  pids+=($!)
done
for i in $(seq 0 $((N-1))); do
  until grep -q HOST_READY $L/r$i.log; do sleep 0.05; done
  python3 -c "import time;print('room$i ready %.2fs'%(time.time()-$t0))"
done
sleep 5
for p in $pids; do ps -o rss= -p $p | awk -v p=$p '{printf "pid %s rss %.0f MB\n", p, $1/1024}'; done
tot=0; for p in $pids; do tot=$((tot+$(ps -o rss= -p $p))); done
echo "N=$N total $((tot/1024)) MB, per room $((tot/1024/N)) MB"
kill $pids 2>/dev/null; wait 2>/dev/null
