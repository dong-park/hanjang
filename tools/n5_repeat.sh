#!/bin/sh
# 한 시험을 N번 되풀이해 종료 코드와 걸린 초를 적는다. 사용: tools/n5_repeat.sh 시험.sh 횟수 로그파일 [출력폴더]
cd "$(dirname "$0")/.." || exit 1
T=$1; N=$2; LOG=$3; D=${4:-/tmp/n5_repeat}
mkdir -p "$D"; : > "$LOG"
i=1
while [ $i -le $N ]; do
  s=$(date +%s)
  sh "$T" > "$D/run$i.out" 2>&1
  c=$?
  e=$(date +%s)
  echo "run$i exit=$c sec=$((e-s)) $(grep -E 'FAIL|PASS' "$D/run$i.out" | tr '\n' ' ' | cut -c1-200)" >> "$LOG"
  i=$((i+1))
done
