# n2-look — 남색 밤 픽셀 룩 부품

> 자기완결 브리프. runner는 상위 spec + 이 파일만 본다. 진행 메모는 이 파일에만 쓴다. `**상태**:` 줄은 손으로 고치지 않는다 — 멈추면 `spec-board node block`, 사람 확인이 필요하면 `spec-board node review`.

**agent**: runner
**id**: HJ-2
**상위**: spec/hanjang/spec.md
**deps**: 없음
**상태**: 아직 안 함
**담당 행**: T34
**사람 확인**: 필요

## 문제

- 모든 화면이 같은 폰트·색·카드 그림을 써야 스토리보드처럼 보인다.
- 카드가 우노 카드를 닮으면 안 된다.

## 목표

모든 화면이 쓰는 테마, 카드 그리기 부품, 아바타, 배경이 생긴다. 미리보기 장면 한 장으로 카드 전 종류를 사람이 눈으로 본다.

## 작업

1. D4 답대로 만든다. 추천 C면 카드와 판은 코드로, 아바타 4종과 아이콘은 픽셀 PNG로 둔다.
2. 갈무리 폰트(일반·굵게)와 OFL 라이선스를 `game/assets/fonts/`에 두고 `game/ui/theme.tres`를 만든다. 버튼·입력칸·패널 모양을 스토리보드 E 스타일로 맞춘다.
3. `game/ui/card_view.gd`가 색 4개와 검정, 숫자 0~9, 스킵·리버스·+2·와일드·와일드+4, 뒷면, 작은 크기·큰 크기, 솟음·어둡게·고름 상태를 그린다. 흰 테두리, 가운데 큰 숫자, 모서리 별이고 기울어진 흰 타원은 없다.
4. `game/ui/avatar_view.gd`가 네모 칸, 이름, 차례 빛남, 회색(끊김), 왕관을 그린다.
5. 배경 점무늬를 그린다.
6. `game/ui/preview.tscn`에 전 종류를 늘어놓고 `--write-movie`로 캡처해 `spec/hanjang/evidence/n2/`에 둔다.

## 완료 기준

- [ ] spec 공통 완료 기준 전부
- [ ] 미리보기 캡처가 evidence/n2/에 있고 카드 15종·뒷면·아바타 4종·버튼·입력칸이 보인다
- [ ] 카드 앞면에 기울어진 흰 타원이 없고 UNO 글자가 없다
- [ ] 폰트 라이선스 파일이 폰트 옆에 있다
- [ ] `engine/Godot.app/Contents/MacOS/Godot --headless --path game --quit`가 오류 없이 끝난다
- [ ] 실경로: 관통이 프로덕션 경로를 탐 (우회 green이면 갭 기록)

## 파일 포인터

| 경로 | 역할 |
|---|---|
| `game/ui/card_view.gd` | 새로 만든다 |
| `game/ui/avatar_view.gd` | 새로 만든다 |
| `game/ui/theme.tres` | 새로 만든다 |
| `game/ui/preview.tscn` | 새로 만든다 |
| `game/assets/` | 새로 만든다 — 폰트·아바타·아이콘 |
| `/Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/pixel-onecard-storyboard/fonts/` | 폰트 원본 (있음) |
| `/Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/pixel-onecard-storyboard/frames/` | 장면 시안 PNG (있음) |

## 구현 메모

- 관련 결정: D4 (막는 결정). 답이 없으면 추천대로 간다. 막는 결정은 답이 올 때까지 시작하지 않는다.
