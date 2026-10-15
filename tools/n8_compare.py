#!/usr/bin/env python3
"""n8: raw/ 캡처에서 장면별 한 장을 골라 evidence/n8/NN-이름.png 로 복사하고, 스토리보드와 2열로 놓은 compare.html 을 만든다.
사용: python3 tools/n8_compare.py   (먼저 ./네창으로_테스트.command 자동, ./네창으로_테스트.command 나감)
"""
import html, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EV = ROOT / "spec/hanjang/evidence/n8"
FRAMES = Path("/Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/pixel-onecard-storyboard/frames")

# (장면 번호, 이름, 캡처 파일, 설명)
PICK = [
    ("01", "title", "자동/01-title-창.png", "첫 화면"),
    ("02", "join", "자동/join/02-join-창.png", "참가 화면"),
    ("03", "lobby", "자동/03-lobby-하늘.png", "대기실 (네 번째로 들어온 창)"),
    ("04", "deal", "자동/04-deal-하늘.png", "나눠 주기"),
    ("05", "my-turn", "자동/05-my-turn-나.png", "내 차례"),
    ("06", "play-fly", "자동/06-play-fly-나.png", "내가 카드를 냄"),
    ("07", "opponent-play", "자동/07-opponent-play-하늘.png", "상대가 카드를 냄"),
    ("08", "wild-picker", "자동/08-wild-picker-하늘.png", "와일드 색 고르기"),
    ("09", "attack", "자동/09-attack-나.png", "공격 카드"),
    ("10", "skip", "자동/10a-skip-나.png", "스킵"),
    ("10b", "reverse", "자동/10b-reverse-나.png", "리버스 (스토리보드 10에 같이 있음)"),
    ("11", "draw-choice", "자동/11-draw-choice-하늘.png", "뽑은 카드 고르기"),
    ("12", "hanjang", "자동/12a-my-hanjang-하늘.png", "한장! 외치기"),
    ("12b", "called", "자동/12b-called-나.png", "한장! 외침 알림"),
    ("12c", "catch-button", "자동/12c-catch-button-나.png", "잡았다! 버튼"),
    ("12d", "caught", "자동/12d-caught-나.png", "잡았다! 결과"),
    ("13", "result", "자동/13-result-하늘.png", "결과 (방장 창)"),
    ("14", "disconnect", "나감/14-disconnect-하늘.png", "접속 끊김"),
]


def main():
    rows = []
    for no, name, src, desc in PICK:
        s = EV / "raw" / src
        if not s.exists():
            print("없음:", s)
            continue
        dst = EV / ("%s-%s.png" % (no, name))
        shutil.copy(s, dst)
        frame = FRAMES / ("%s.png" % no[:2])
        rows.append((no, name, desc, frame, dst))
    out = ["<!doctype html><meta charset=utf-8><title>n8 스토리보드 대조</title>",
           "<style>body{background:#0e1230;color:#dfe5ff;font:15px sans-serif;margin:24px}",
           "table{border-collapse:collapse}td{padding:8px;vertical-align:top}img{width:560px;border:1px solid #445}",
           "h3{margin:20px 0 4px}</style><h1>한장! 스토리보드 vs 실제 창 (4창 자동 한 판)</h1>",
           "<p>왼쪽 스토리보드 frames, 오른쪽 실제 Godot 창 캡처(1152×648). 다른 점은 diff.md 참고.</p><table>"]
    for no, name, desc, frame, dst in rows:
        out.append("<tr><td colspan=2><h3>%s %s — %s</h3></td></tr><tr><td><img src='file://%s'></td><td><img src='%s'></td></tr>"
                   % (no, name, html.escape(desc), frame, dst.name))
    out.append("</table>")
    (EV / "compare.html").write_text("\n".join(out), encoding="utf-8")
    print("compare.html:", len(rows), "장면")


main()
