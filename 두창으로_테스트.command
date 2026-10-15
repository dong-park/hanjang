#!/bin/zsh
# 같은 컴퓨터에서 창 두 개를 띄운다: 하나는 방장, 하나는 접속.
cd "${0:A:h}"
GODOT="./engine/Godot.app/Contents/MacOS/Godot"
"$GODOT" --path game -- --host &
sleep 1.5
"$GODOT" --path game -- --join=127.0.0.1 &
wait
