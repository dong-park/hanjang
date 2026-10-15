# n4-session — 방장 판정 게임 세션

> 자기완결 브리프. runner는 상위 spec + 이 파일만 본다. 진행 메모는 이 파일에만 쓴다. `**상태**:` 줄은 손으로 고치지 않는다 — 멈추면 `spec-board node block`, 사람 확인이 필요하면 `spec-board node review`.

**agent**: runner
**id**: HJ-4
**상위**: spec/hanjang/spec.md
**deps**: n1-rules, n3-lobby
**상태**: 끝남
**담당 행**: T7, T8, T9, T26
**사람 확인**: 불필요

## 문제

- 판정이 방장 한 곳에 있어야 속임수와 엇갈림이 없다.
- 접속자에게 남의 패가 가면 안 된다.

## 목표

방장이 n1 엔진을 들고 판을 돌린다. 접속자는 요청만 보내고 자기 판 상태만 받는다. 4명이 헤드리스로 한 판을 끝까지 같은 결과로 마친다.

## 작업

1. `game/net/session.gd`가 n3 시작 신호를 받아 n1 엔진을 만들고, 바뀔 때마다 자리별 `snapshot_for`를 `rpc_id`로 보낸다.
2. 요청 RPC: 내기, 뽑기, 뽑은 카드 바로 내기·가지기, 색 고르기, 한장!, 잡았다!. 차례 아님·패에 없음·낼 수 없음·같은 요청 두 번은 무시하고 로그를 남긴다.
3. 차례 시간(D1, 추천 20초)을 방장이 잰다. 다 되면 한 장 뽑고 넘긴다. 색 고르기 시간 끝은 가장 많은 색, 바로 내기 시간 끝은 가지기. 한장! 3초 창, D8 추천대로 판정 중에는 다음 차례를 멈춘다.
4. 판 중 접속자가 나가면 n1 나간 자리 처리를 부르고 모두에게 알린다.
5. 시험 인자 `--autoplay`(낼 수 있는 첫 카드를 내고 가끔 한장!을 잊음), `--seed=N`, `--cheat`(잘못된 요청을 보냄)를 쓴다.
6. `game/tests/test_net_game.sh`가 방장+3명을 `--autoplay --seed=7`로 띄워 한 판을 끝내고, 네 로그의 등수가 같은지, `--cheat` 요청이 무시됐는지 판정한다.

## 완료 기준

- [ ] spec 공통 완료 기준 전부
- [ ] `sh game/tests/test_net_game.sh`가 종료 코드 0
- [ ] 네 접속자 로그의 최종 등수가 같다
- [ ] 접속자 로그에 남의 패 카드 값이 한 번도 찍히지 않는다
- [ ] `--cheat` 요청마다 방장 로그에 무시 기록이 있다
- [ ] 시간이 다 된 차례에 자동 뽑기 로그가 있다
- [ ] 실경로: 관통이 프로덕션 경로를 탐 (우회 green이면 갭 기록)

## 파일 포인터

| 경로 | 역할 |
|---|---|
| `game/net/session.gd` | 새로 만든다 |
| `game/rules/rules.gd` | n1이 만든다 — 읽기만 |
| `game/net/room.gd` | n3이 만든다 — 시그널만 쓴다 |
| `game/tests/test_net_game.sh` | 새로 만든다 |

## 구현 메모

- 관련 결정: D1 → 20초, D8 → 판정 중 다음 차례 멈춤 (2026-10-15 사용자 답).
- 웨이브 1 리뷰에서 넘어온 일 (wave-20261015-1606.md): 같은 요청 두 번은 첫 번째만 받도록 방장이 (자리, 요청 번호)로 중복을 거른다. 자리는 접속자가 보낸 값이 아니라 보낸 peer id로만 정한다. 한장! 창은 3초 뒤 세션이 `close_hanjang()`을 부른다 — 엔진은 시간을 재지 않는다.
- 엔진 API는 `game/rules/rules.gd` 머리 주석(1~40줄)에 있다: setup, play, choose_color, draw, keep_drawn, call_hanjang, catch_hanjang, close_hanjang, auto_color, leave, ranking, snapshot_for.
- 시험에 아직 없는 경우(P2): 한장! 창이 열린 채 나감, 2인 와일드+4 중복 요청, setup 전 snapshot_for. 세션 시험에서 덮는다.
- 웨이브 3 리뷰 넘김 (wave-20261015-1630.md): 판 화면 `table.gd`의 입력 잠금(_locked)은 판 상태를 새로 받을 때만 풀린다. 방장이 요청을 거절하면 그 접속자에게 거절 알림을 보내 잠금을 풀 수 있게 한다(화면 쪽 연결은 n7).
- 차례 시간은 D1 답대로 20초다. n5 로컬 드라이버의 시간 바는 15초로 만들어져 있으니, 세션이 보내는 남은 시간을 기준으로 삼는다.

## 진행 메모 (runner)

- `game/net/session.gd`를 autoload `Session`으로 등록했다(project.godot). `Room.game_started`에서 방장이 0.3초 뒤 엔진을 만들고 자리별 `snapshot_for`(+ `time_left`, `turn_time`)를 `rpc_id`로 보낸다.
- 화면 쪽 면: `Session.request(kind,a,b)`, 시그널 `state_changed` `request_refused(rid,reason)` `player_left` `ended`. 거절 알림으로 table.gd 입력 잠금을 풀 수 있다(연결은 n7).
- 중복 거름: (자리, 요청 번호). 자리는 `get_remote_sender_id`로만 정한다. 중복·차례 아님·패에 없음·낼 수 없음은 방장 로그에 `IGNORED seat= rid= kind= reason=`.
- 시간: 기본 20초(`--turn-time`), 한장! 창 3초(`--hj-time`). 끝나면 뽑기(+뽑은 카드 가지기) / 색은 auto_color / 한장! 창은 close_hanjang. 판정 중에는 엔진이 내기·뽑기를 거절해 차례가 멈춘다.
- 시험: `sh game/tests/test_net_game.sh` 종료 코드 0(판1 4인 등수 일치·LEAK 0·cheat 93건 전부 무시 기록·AUTO_DRAW 20건, 판2 3인 중 1명 판 중 나감 후 완주). `test_session_edge.gd`로 P2 3건(한장! 창 연 채 나감, 2인 와일드+4 중복, setup 전 엔진) 확인.
- 갭: (1) `--seed=7`은 덱만 고정한다. autoplay가 시간(타이머) 기반이라 우승자는 실행마다 다를 수 있다 — 기준은 "네 로그 등수 일치". (2) 접속자 비공개는 받은 상태에 hand·top 밖의 카드가 있으면 `LEAK`로 찍는 방식으로 확인했다(패킷 캡처 아님). (3) 실제 판 화면 연결(table.gd↔Session)은 n7 몫이라 지금 경로는 autoplay 드라이버다. (4) rules.gd `snapshot_for`는 setup 전에 부르면 깨진다 — 세션은 엔진 생성 뒤에만 부른다. (5) 판 종료 뒤 다시 하기/대기실로는 n7.
