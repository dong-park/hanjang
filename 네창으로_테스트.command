#!/bin/zsh
# 같은 컴퓨터에서 창 네 개를 띄운다: 방장 1개 + 접속 3개.
#   ./네창으로_테스트.command        접속 창 셋은 자동 플레이, 방장 창은 사람이 한다 (시작 버튼은 사람이 누른다)
#   ./네창으로_테스트.command 자동   네 창 모두 자동 플레이. 방장이 알아서 시작하고, 장면 캡처를 spec/hanjang/evidence/n8/raw/ 에 저장한다
#   ./네창으로_테스트.command 나감   자동 + 체리 창이 판 중에 나간다 (장면 14 캡처용)
cd "${0:A:h}"
GODOT="./engine/Godot.app/Contents/MacOS/Godot"
MODE="${1:-}"
AUTO=(--autoplay --seed=7 --turn-time=3 --hj-time=2 --auto-delay=0.4)
HOST_ARGS=(--host --name=하늘 --face=0)
JOIN_EXTRA=()
if [ "$MODE" = "자동" ] || [ "$MODE" = "나감" ]; then
  RAW="spec/hanjang/evidence/n8/raw/${MODE}"
  rm -rf "$RAW" && mkdir -p "$RAW"
  RAW="$PWD/$RAW"
  if [ "$MODE" = "자동" ]; then  ## 첫 화면·참가 화면은 명령줄 접속이 건너뛰므로 따로 한 장씩 띄워 찍는다
    "$GODOT" --path game -- --shots="$RAW" --name=첫화면 --quit-after=2
    "$GODOT" --path game -- --shots="$RAW/join" --name=참가 --shot=join --quit-after=2
  fi
  AUTO_ALL=($AUTO --keep-open --quit-after=${QUIT_AFTER:-200} --shots="$RAW")
  HOST_ARGS=($HOST_ARGS $AUTO_ALL --try-start=5)
  JOIN_EXTRA=($AUTO_ALL)
else
  JOIN_EXTRA=($AUTO)
fi
"$GODOT" --path game -- $HOST_ARGS &
sleep 1.5
"$GODOT" --path game -- --join=127.0.0.1 --name=나 --face=1 $JOIN_EXTRA &
sleep 0.5
"$GODOT" --path game -- --join=127.0.0.1 --name=민트 --face=2 $JOIN_EXTRA &
sleep 0.5
if [ "$MODE" = "나감" ]; then
  "$GODOT" --path game -- --join=127.0.0.1 --name=체리 --face=3 $JOIN_EXTRA --leave-after=22 &
else
  "$GODOT" --path game -- --join=127.0.0.1 --name=체리 --face=3 $JOIN_EXTRA &
fi
wait
