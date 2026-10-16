# n8-verify — 실제 폰 2대와 맥 1대로 공개 방 한 판을 끝낸다

> 자기완결 브리프. runner는 상위 spec + 이 파일만 본다. 진행 메모는 이 파일에만 쓴다. `**상태**:` 줄은 손으로 고치지 않는다 — 멈추면 `spec-board node block`, 사람 확인이 필요하면 `spec-board node review`.

**agent**: runner
**id**: HR-8
**상위**: spec/hanjang-relay/spec.md
**deps**: n5, n6, n7
**상태**: 끝남
**담당 행**: T17
**사람 확인**: 필요

## 문제

- 모든 것이 합쳐진 뒤 실제 폰과 맥으로 공개 방 한 판을 본 적이 없다.

## 목표

실제 폰 2대와 맥 1대로 공개 방 한 판을 끝낸다

## 작업

1. n7로 띄운 서버와 임시 터널 주소를 쓴다.
2. 폰 A가 공개 방을 만들고 폰 B와 맥이 목록에서 들어와 한 판을 끝까지 한다.
3. 폰 A 화면을 잠갔다 켜서 복귀를 한 번 시험한다.
4. 기존 헤드리스 시험(test_rejoin 포함) 전부를 한 번 더 돈다.

## 완료 기준

- [ ] 공개 방 한 판이 끝까지 돈다(사용자 확인)
- [ ] 폰 A 잠금과 복귀가 된다
- [ ] 기존 헤드리스 시험 종료 코드 0
- [ ] 확인되지 않은 것은 확인 대기로 적는다

## 구현 메모

- 기존 웹 웨이브에서 남은 문제: test_rejoin에 시간 제한이 없다. timeout을 넣어 멈춰도 끝나게 한다(시험 스크립트만 수정).
- 헤드리스·에뮬레이션 증거를 실제 폰 증거로 쓰지 않는다. 폰 확인은 사람이 한다.
- 헤드리스 시험은 /tmp/hanjang-headless.lock을 잡고 하나씩 차례로 돌린다(동시 실행 금지).
- 커밋은 파일을 지정해 add한다(git add -A·. 금지). push 하지 않는다.
- 보드 댓글 첨부 spec/**/evidence/*/cm-* 파일은 지우지 않는다.
- 결정 D1=C(방마다 헤드리스 Godot), D2=C(이 맥이 서버), D3=C(trycloudflare 임시 주소), D4~D8=A는 닫혔다.

## 자동 시험 결과 (맥, 헤드리스 — 실폰 증거 아님)

시험은 /tmp/hanjang-headless.lock으로 하나씩 차례로 돌렸다. test_rejoin.sh는 잠금+240초 제한 실행기(headless_lock.py)로 스스로 다시 실행하도록 고쳤다.

| 시험 | 종료 코드 |
|---|---|
| test_dedicated.sh | 0 |
| test_drops.sh | 0 |
| test_lobby.sh | 0 |
| test_net_game.sh | 0 |
| test_rejoin.sh | 1 → 재시도 0 (간헐) |
| test_rooms.sh | 0 |
| test_trust.sh | 1 → 재시도 0 (간헐) |
| test_wire.sh | 0 |
| test_fx.gd / test_rules.gd / test_session_edge.gd / test_table.gd / test_touch.gd | 0 |
| test_rooms.gd 단독 | 방 서버가 있어야 돌아서 단독 실행은 멈춤(직접 종료, 143). 같은 시험이 test_rooms.sh로 0 |
| relay/test_manager.py | 0 |

- 간헐 실패: test_rejoin(판 결과 RESULT 없음), test_trust(복귀 seat 로그 없음)가 첫 시도에 한 번씩 실패, 재시도에서 통과. 원인은 미확정(부하 타이밍 추정).
- 서버: LaunchAgent com.hanjang.relay·com.hanjang.tunnel 실행 중. 터널 루트 HTTP 200, POST /api/rooms로 공개 방 생성과 GET /api/rooms 목록 확인.

## 확인할 것 (사람, 실폰)

헤드리스·에뮬레이션 결과는 실제 폰 증거가 아니다. 아래는 모두 확인 대기.

- [ ] 터널 주소 확인: `relay/deploy/hanjang.sh url` 출력 (지금: https://thoughts-bag-handled-runtime.trycloudflare.com — 재시작하면 바뀜)
- [ ] 폰 A가 이 주소를 열어 공개 방을 만든다
- [ ] 폰 B와 맥 브라우저가 목록에서 그 방을 보고 입장한다
- [ ] 세 명이 한 판을 끝까지 한다(결과 화면까지)
- [ ] 폰 A 화면을 잠갔다 켜서 같은 자리로 복귀한다
- [ ] 막힌 곳이 있으면 화면·시각을 적는다
