#!/bin/zsh
cd "${0:A:h}/.."
mkdir -p build/web
./engine/Godot.app/Contents/MacOS/Godot --headless --path game --export-release Web ../build/web/index.html
