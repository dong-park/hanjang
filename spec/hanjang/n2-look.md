# n2-look — 남색 밤 픽셀 룩 부품

> 자기완결 브리프. runner는 상위 spec + 이 파일만 본다. 진행 메모는 이 파일에만 쓴다. `**상태**:` 줄은 손으로 고치지 않는다 — 멈추면 `spec-board node block`, 사람 확인이 필요하면 `spec-board node review`.

**agent**: runner
**id**: HJ-2
**상위**: spec/hanjang/spec.md
**deps**: 없음
**상태**: 확인 대기
**담당 행**: T34
**사람 확인**: 필요

## 문제

- 모든 화면이 같은 폰트·색·카드 그림을 써야 스토리보드처럼 보인다.
- 카드가 우노 카드를 닮으면 안 된다.

## 목표

모든 화면이 쓰는 테마, 카드 그리기 부품, 아바타, 배경이 생긴다. 미리보기 장면 한 장으로 카드 전 종류를 사람이 눈으로 본다.

## 작업

1. D4 답은 B다. 카드와 화면 부품을 모두 픽셀 그림 파일(PNG)로 만든다. 모든 그림은 같은 픽셀 크기 배율로 그리고, Godot 가져오기는 필터 끄기(Nearest)로 둔다.
2. 카드 그림: 색 4개 × 숫자 0~9·스킵·리버스·+2, 검정 와일드·와일드+4, 뒷면을 `game/assets/cards/`의 시트 한 장(또는 카드별 파일)으로 만든다. 흰 테두리, 가운데 큰 숫자, 모서리 별, 두께 그림자를 그림에 넣는다. 기울어진 흰 타원과 UNO 글자는 없다.
3. 화면 부품 그림: 패널·버튼·입력칸(9칸 늘림용), 네모 아바타 칸(보통·차례 빛남·회색), 왕관, 방향 고리 화살표, 시간 바, 배경 점무늬 타일을 `game/assets/ui/`에 만든다. 아바타 얼굴 4종은 `game/assets/avatars/`에 둔다.
4. 갈무리 폰트(일반·굵게)와 OFL 라이선스를 `game/assets/fonts/`에 두고, 위 그림으로 `game/ui/theme.tres`를 만든다.
5. `game/ui/card_view.gd`는 카드 값에 맞는 그림을 골라 보여 주고, 솟음·어둡게·고름·작은 크기·큰 크기 상태만 바꾼다. `game/ui/avatar_view.gd`는 아바타 그림과 이름, 상태를 보여 준다.
6. 그림을 만든 방법(직접 찍기, 스크립트 생성, 이미지 생성 후 다듬기)을 구현 메모에 적는다. 다시 만들 수 있게 원본도 레포에 둔다.
7. `game/ui/preview.tscn`에 전 종류를 늘어놓고 `--write-movie`로 캡처해 `spec/hanjang/evidence/n2/`에 둔다.

## 완료 기준

- [x] spec 공통 완료 기준 전부
- [x] 미리보기 캡처가 evidence/n2/에 있고 카드 15종·뒷면·아바타 4종·버튼·입력칸이 보인다
- [x] 카드 앞면에 기울어진 흰 타원이 없고 UNO 글자가 없다
- [x] 폰트 라이선스 파일이 폰트 옆에 있다
- [x] `engine/Godot.app/Contents/MacOS/Godot --headless --path game --quit`가 오류 없이 끝난다
- [ ] 실경로: 관통이 프로덕션 경로를 탐 (우회 green이면 갭 기록)

## 파일 포인터

| 경로 | 역할 |
|---|---|
| `game/ui/card_view.gd` | 새로 만든다 |
| `game/ui/avatar_view.gd` | 새로 만든다 |
| `game/ui/theme.tres` | 새로 만든다 |
| `game/ui/preview.tscn` | 새로 만든다 |
| `game/assets/cards/` | 새로 만든다 — 카드 그림 |
| `game/assets/ui/` | 새로 만든다 — 패널·버튼·아바타 칸·고리·배경 그림 |
| `game/assets/avatars/` | 새로 만든다 — 아바타 얼굴 4종 |
| `game/assets/fonts/` | 새로 만든다 — 갈무리 폰트와 라이선스 |
| `/Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/pixel-onecard-storyboard/fonts/` | 폰트 원본 (있음) |
| `/Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/pixel-onecard-storyboard/frames/` | 장면 시안 PNG (있음) |

## 구현 메모

- 관련 결정: D4 → B (2026-10-15, 사용자가 보드에서). 카드와 화면을 모두 픽셀 그림 파일로 만든다. 추천은 C였다.

- 만든 방법: 스크립트 생성. 원본은 `tools/gen_look.py`(Pillow). 5x7·3x5 픽셀 글자 격자와 도형으로 작은 격자에 그린 뒤 정수 4배로 키워 PNG 저장. 테마(`theme.tres`)와 아바타·폰트 복사도 같은 스크립트가 다시 만든다. 카드는 카드별 파일 `game/assets/cards/<색>_<값>.png`(색 red/yellow/green/blue, 값 0`9·skip·reverse·plus2), `wild.png`, `wild4.png`, `back.png`.
- 필터 끄기: `project.godot`의 기본 텍스처 필터를 Nearest(0)로 둔다. CardView·AvatarView는 노드에도 Nearest를 둔다. 폰트는 antialiasing·hinting 끔(.import).
- 카드 값 표기(가정): CardView는 색 문자열과 값 문자열을 받는다. n1의 카드 표현과 다르면 n5에서 변환한다. 크기는 작게 0.5, 보통 1.0(80x112), 크게 1.5 배.
- 폰트: Galmuri11.ttf와 굵은 글씨. 굵은 글씨는 원본이 woff2뿐인데 Godot 4.7.2가 woff2를 못 읽어(FreeType 오류) fontTools로 TTF로 바꿔 `Galmuri11-Bold.ttf`로 두었다. 라이선스 `OFL.txt`는 폰트 옆에 있다. 저작권 줄은 원본 파일에 없어 일반 문구로 썼으니 원본 라이선스로 바꿔 넣을 것.
- 시험: `game/tests/look_test.gd`(--script)로 카드 55종 그림, 크기, 상태, 테마 로드를 확인한다. n1의 `test_rules.gd`도 다시 돌려 통과.
- 갭: 미리보기 장면만 있고 프로덕션 화면(n3, n5)에는 아직 안 물렸다. 스킵 카드 그림은 작은 격자라 ⊘ 모양이 도넛처럼 보인다. 사람 눈 확인 후 다듬을지 정한다.

## 확인할 것

미리보기 한 장(`spec/hanjang/evidence/n2/preview-cards-ui.png`)을 보고 카드 그림이 우노 카드와 닮지 않았는지, 숫자와 기호가 읽히는지 본다.

- [ ] 카드 15종(숫자 0`9, 스킵, 리버스, +2, 와일드, 와일드+4)과 뒷면이 구분된다
- [ ] 카드 앞면에 기울어진 흰 타원과 UNO 글자가 없다
- [ ] 스킵 카드 그림(⊘)이 읽힌다. 안 읽히면 고쳐 달라고 답한다
- [ ] 아바타 4종, 버튼, 입력칸, 시간 바가 남색 밤 톤으로 어울린다
