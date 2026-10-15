# n5-table — 판 화면과 내 손 조작

> 자기완결 브리프. runner는 상위 spec + 이 파일만 본다. 진행 메모는 이 파일에만 쓴다. `**상태**:` 줄은 손으로 고치지 않는다 — 멈추면 `spec-board node block`, 사람 확인이 필요하면 `spec-board node review`.

**agent**: runner
**id**: HJ-5
**상위**: spec/hanjang/spec.md
**deps**: n1-rules, n2-look
**상태**: 확인 대기
**담당 행**: T17, T18, T19, T20, T21, T24, T25
**사람 확인**: 필요

## 문제

- 처음 하는 사람도 잘못 내지 않게 낼 카드만 솟아야 한다.
- 네트워크를 기다리지 않고 화면을 먼저 만들어야 일이 빨리 끝난다.

## 목표

장면 05·06·07·08·11이 로컬에서 동작한다. 판 화면은 n1 판 상태 하나만 보고 그려지고, 행동은 하나의 출구로 나간다.

## 작업

1. `game/screens/table.tscn`에 4자리 배치, 더미 둘, 방향 고리, 내 아바타와 시간 바, 뽑기 버튼을 스토리보드 좌표대로 놓는다.
2. `game/ui/hand_view.gd`: 부채꼴 패, 낼 수 있는 카드만 솟고 나머지 어둡게, 누르거나 위로 끌면 내기. 어두운 카드는 반응 없음.
3. 내 카드가 더미로 날아가는 연출, 상대 카드가 그 자리에서 가운데로 날아오는 연출.
4. 와일드 색 고르기 팝업(장면 08), 뽑은 카드 크게 보이기와 바로 내기·가지기(장면 11).
5. 화면은 `apply_snapshot(dict)`로만 그리고 행동은 `action_requested` 시그널 하나로 낸다. 형태는 n1 주석을 따른다.
6. `game/screens/table_local.gd`: n1 엔진을 직접 돌리는 혼자 시험용 드라이버. 나머지 세 자리는 자동으로 낸다.

## 완료 기준

- [x] spec 공통 완료 기준 전부
- [x] `--local` 인자로 판 화면이 뜨고 혼자 한 판을 끝까지 할 수 있다
- [x] 장면 05·06·07·08·11 캡처가 evidence/n5/에 있다
- [x] 어두운 카드를 눌렀을 때 행동이 나가지 않음을 로그로 확인한다
- [x] 판 화면 코드에 네트워크 호출이 없다
- [ ] 실경로: 관통이 프로덕션 경로를 탐 (우회 green이면 갭 기록)

## 파일 포인터

| 경로 | 역할 |
|---|---|
| `game/screens/table.tscn` | 새로 만든다 |
| `game/screens/table.gd` | 새로 만든다 |
| `game/ui/hand_view.gd` | 새로 만든다 |
| `game/ui/wild_picker.tscn` | 새로 만든다 |
| `game/ui/draw_choice.tscn` | 새로 만든다 |
| `game/screens/table_local.gd` | 새로 만든다 |
| `game/ui/card_view.gd` | n2가 만든다 |

## 구현 메모

- 관련 결정: 없음 (2026-10-15 사용자 답).
- 웨이브 1 리뷰에서 넘어온 일 (wave-20261015-1606.md): 규칙 엔진의 카드는 색 정수와 kind(num, skip, rev, draw2, wild, wild4)이고, CardView는 색 문자열과 값 문자열(0~9, skip, reverse, plus2, wild, wild4)을 받는다. 둘을 바꾸는 함수를 한 곳에만 둔다.
- n2 통과(2026-10-15). 카드 그림은 2배, 화면 부품은 4배 배율이라 픽셀 크기가 다르다. 판 화면에서 어색하면 구현 메모에 적고 캡처로 보인다.
- 구현 (runner): 규칙 엔진 카드 ↔ CardView 값 변환은 `game/ui/card_map.gd` 한 곳. 판 화면은 `apply_snapshot`과 `action_requested`({type: play|choose_color|draw|keep})만 쓴다. play는 카드 id로 낸다(엔진 idx 변환은 드라이버가 한다).
- 판 화면의 낼 수 있는 카드 판정(`is_playable`)은 rules.gd `can_play`의 복사본이다(스냅샷에 낼 수 있음 표시가 없어서). 시험이 둘의 일치를 확인한다. n7에서 세션 스냅샷이 바뀌면 같이 본다.
- 닉네임·얼굴·방장은 스냅샷에 없어 `set_players(names, faces, host)`로 받는다. 시간 바는 `set_time(left, total)`로 받는다(로컬 드라이버는 15초).
- 실경로 갭: 한장! 외치기·잡았다! 화면은 n6 몫이라 로컬 드라이버가 낸 사람이 바로 외친 것으로 넘긴다. 날기 시간은 0.32초로 정했고 사람이 봐야 한다. 시험은 SubViewport에 실제 마우스 이벤트를 넣어 눌러 보았다(어두운 카드는 로그 `HAND ignored card`).
- 크기: 카드 그림 2배·부품 4배 차이는 판 화면에서 눈에 띄는 어색함 없음(캡처 evidence/n5/).
- 시험: `--script res://tests/test_table.gd`, 캡처: `tests/capture_table.gd`(창이 떠야 함). `main.gd`에 `--local` 분기 3줄 추가.

## 확인할 것

로컬 드라이버로만 돈 화면이다. 아래는 사람이 눈으로 볼 것이다.

- [ ] 장면 05·06·07·08·11 캡처가 스토리보드와 맞는가 (evidence/n5/)
- [ ] 카드 날기 0.32초와 시간 바 15초가 적당한가
- [ ] 낼 수 없는 카드가 어둡고 반응 없는가

- 웨이브 리뷰 P2: table.gd의 _locked는 apply_snapshot에서만 풀린다. 방장이 행동을 거절하면 풀리지 않으니 n4/n7에서 거절 신호로 풀 것.
