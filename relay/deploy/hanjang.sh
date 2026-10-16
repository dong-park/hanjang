#!/bin/bash
# 한장! 관리 서비스 + 임시 터널을 이 맥의 사용자 LaunchAgent로 관리한다 (sudo 필요 없음).
#   hanjang.sh print      plist 내용만 출력 (시스템 변경 없음)
#   hanjang.sh install    plist 쓰기 + 서비스 시작 (여러 번 돌려도 같은 결과)
#   hanjang.sh url        현재 임시 주소(https/wss) 출력
#   hanjang.sh status     launchctl list 확인
#   hanjang.sh restart    서비스만 재시작 (방은 사라진다)
#   hanjang.sh uninstall  서비스 내리고 plist 삭제
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${HANJANG_PORT:-8070}"
UIDN="$(id -u)"
AGENTS="$HOME/Library/LaunchAgents"
LOGS="$HOME/Library/Logs/hanjang"
RELAY_LABEL="com.hanjang.relay"
TUNNEL_LABEL="com.hanjang.tunnel"
PY="$(command -v python3)"
CF="$(command -v cloudflared || true)"
CAFF=/usr/bin/caffeinate

plist() { # label workdir logname args...
  local label="$1" wd="$2" log="$3"; shift 3
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  echo '<plist version="1.0"><dict>'
  echo "  <key>Label</key><string>$label</string>"
  echo "  <key>WorkingDirectory</key><string>$wd</string>"
  echo "  <key>ProgramArguments</key><array>"
  echo "    <string>$CAFF</string><string>-i</string>"   # 서비스가 도는 동안 잠자기 방지
  for a in "$@"; do echo "    <string>$a</string>"; done
  echo "  </array>"
  echo "  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string></dict>"
  echo "  <key>RunAtLoad</key><true/>"
  echo "  <key>KeepAlive</key><true/>"
  echo "  <key>ThrottleInterval</key><integer>3</integer>"
  echo "  <key>StandardOutPath</key><string>$LOGS/$log.log</string>"
  echo "  <key>StandardErrorPath</key><string>$LOGS/$log.log</string>"
  echo '</dict></plist>'
}
relay_plist()  { plist "$RELAY_LABEL" "$ROOT" relay "$PY" "$ROOT/relay/manager.py" "$PORT"; }
tunnel_plist() { plist "$TUNNEL_LABEL" "$ROOT" tunnel "$CF" tunnel --config /dev/null --no-autoupdate --url "http://127.0.0.1:$PORT"; }

load() { # label file : 이미 있으면 내렸다가 다시 올린다
  launchctl bootout "gui/$UIDN/$1" 2>/dev/null || true
  launchctl bootstrap "gui/$UIDN" "$2"
}

case "${1:-}" in
  print) relay_plist; tunnel_plist ;;
  install)
    [ -n "$CF" ] || { echo "cloudflared가 없어요 (brew install cloudflared)" >&2; exit 1; }
    mkdir -p "$AGENTS" "$LOGS"
    relay_plist > "$AGENTS/$RELAY_LABEL.plist"
    tunnel_plist > "$AGENTS/$TUNNEL_LABEL.plist"
    load "$RELAY_LABEL" "$AGENTS/$RELAY_LABEL.plist"
    : > "$LOGS/tunnel.log"
    load "$TUNNEL_LABEL" "$AGENTS/$TUNNEL_LABEL.plist"
    "$0" url ;;
  url)
    for _ in $(seq 1 40); do
      u="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOGS/tunnel.log" 2>/dev/null | tail -1 || true)"
      [ -n "$u" ] && { echo "$u"; echo "wss://${u#https://}/ws/<방코드>"; exit 0; }
      sleep 1
    done
    echo "주소를 아직 못 받았어요: $LOGS/tunnel.log 확인" >&2; exit 1 ;;
  status) launchctl list | grep -E 'com\.hanjang\.' || { echo "등록된 서비스 없음"; exit 1; } ;;
  restart) launchctl kickstart -k "gui/$UIDN/$RELAY_LABEL" ;;
  uninstall)
    for l in "$RELAY_LABEL" "$TUNNEL_LABEL"; do
      launchctl bootout "gui/$UIDN/$l" 2>/dev/null || true
      [ -f "$AGENTS/$l.plist" ] && mv "$AGENTS/$l.plist" "$HOME/.Trash/$l.plist.$(date +%s)" || true
    done ;;
  *) sed -n 2,8p "$0"; exit 2 ;;
esac
