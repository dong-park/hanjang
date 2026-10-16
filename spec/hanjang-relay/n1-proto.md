# n1-proto — 이 맥에서 헤드리스 방 프로세스 하나의 비용을 재고, 폰 브라우저가 trycloudflare wss로 방에 들어간다

> 자기완결 브리프. runner는 상위 spec + 이 파일만 본다. 진행 메모는 이 파일에만 쓴다. `**상태**:` 줄은 손으로 고치지 않는다 — 멈추면 `spec-board node block`, 사람 확인이 필요하면 `spec-board node review`.

**agent**: runner
**id**: HR-1
**상위**: spec/hanjang-relay/spec.md
**deps**: 
**상태**: 끝남
**담당 행**: T1, T2
**사람 확인**: 필요

## 문제

- 방을 헤드리스 Godot가 들고 브라우저가 wss로 붙는지 아직 숫자로 모른다.
- 서버가 이 맥이라 서버 접근 확인은 필요 없고, 대신 이 맥의 헤드리스 방 비용과 터널 연결을 재야 한다.

## 목표

이 맥에서 헤드리스 방 프로세스 하나의 비용을 재고, 폰 브라우저가 trycloudflare wss로 방에 들어간다

## 작업

1. 이 맥의 uname, CPU, 메모리, godot·cloudflared·python3 버전을 구현 메모에 적는다(T1은 ssh 대신 로컬 확인으로 바꿔 읽는다).
2. 헤드리스 Godot 방 1개와 4개를 띄워 시작 시간과 방당 메모리(RSS)를 잰다. 여기서 동시 방 수 한도를 계산한다.
3. cloudflared 임시 터널(trycloudflare)을 7777에 붙이고 wss 주소를 얻는다.
4. 폰 Safari에서 그 주소로 닉네임을 넣고 대기실이 뜨는지, 맥 쪽에도 닉네임이 보이는지 본다(T2).

## 완료 기준

- [x] 이 맥 사양과 설치 목록이 구현 메모에 있다
- [x] 방 1개·4개의 시작 시간과 메모리 숫자가 있다
- [ ] 폰 브라우저가 wss로 대기실에 들어가고 캡처가 있다
- [x] 코드는 바뀌지 않았다(재는 스크립트만 추가)

## 구현 메모

- game/net/room.gd의 ?room= 쿼리 변경이 커밋된 뒤에 시작한다.
- 터널을 못 붙이면 막힘으로 보내고 오류 문구를 적는다. 임시 주소는 실행마다 바뀐다.
- 정리: D3=C라 이름 있는 터널과 도메인은 나중 결정이다. 여기서는 정하지 않는다.
- 헤드리스 시험은 /tmp/hanjang-headless.lock을 잡고 하나씩 차례로 돌린다(동시 실행 금지).
- 커밋은 파일을 지정해 add한다(git add -A·. 금지). push 하지 않는다.
- 보드 댓글 첨부 spec/**/evidence/*/cm-* 파일은 지우지 않는다.
- 결정 D1=C(방마다 헤드리스 Godot), D2=C(이 맥이 서버), D3=C(trycloudflare 임시 주소), D4~D8=A는 닫혔다.

### 실행 결과 (2026-10-16, runner)

- 이 맥: Darwin 27.0 arm64, Apple M1 Pro 8코어, 메모리 32GB, macOS 27.0.1. godot는 PATH에 없고 engine/Godot.app(4.7.2) 사용, cloudflared 2026.5.2, python3 3.13.0, node 있음.
- 측정(tools/n1_measure.sh, 헤드리스 방 `--host`): 방 1개 HOST_READY까지 0.72초, RSS 약 194MB. 방 4개는 0.75~0.85초 안에 모두 준비, 방당 약 196MB(합 786MB). 한도 계산: OS와 다른 일에 8GB를 남기면 24GB/196MB, 약 120개. 유휴 방 기준이라 판 중에는 더 늘 수 있다(n8에서 확인).
- 터널 함정: ~/.cloudflared/config.yml에 worldcup 이름 있는 터널 ingress가 있어 `cloudflared tunnel --url`이 전부 404가 된다. 임시 터널은 `--config /dev/null`을 줘야 붙는다(사용자 설정은 건드리지 않음). 새 주소는 DNS가 퍼지기까지 10~20초 걸리니 그 전에 조회하면 이름이 안 풀린 채 캐시될 수 있다.
- 맥 자동 확인(폰 확인이 아님): Playwright Chromium이 공개 https 페이지를 열고 `--join=wss://…`로 접속, 대기실에 '서버(방장)'와 '맥브라우저(준비 완료)'가 2/4명으로 보였다. 방 로그에 SEATED 2 맥브라우저. 캡처는 evidence/n1/mac-lobby.png.
- 이 방에 폰이 들어갈 때 닉네임이 맥에서 보이는 방법: `tail -f /tmp/n1/room.log`에 `SEATED <자리> <닉네임>`이 찍힌다.

### 지금 떠 있는 것 (nohup 상당, 세션에서 분리됨)

| 무엇 | PID | 로그 |
|---|---|---|
| 방 서버(헤드리스 Godot, 7777) | 55882 | /tmp/n1/room.log |
| 웹 서버(build/web, 8060) | 55883 | /tmp/n1/web.log |
| 터널 → 7777 (wss) | 59424 | /tmp/n1/tun-ws.log |
| 터널 → 8060 (페이지) | 59425 | /tmp/n1/tun-web.log |

- wss 주소: wss://headset-deserve-epinions-fcc.trycloudflare.com
- 폰에서 열 페이지: https://naval-computer-infections-note.trycloudflare.com/?room=wss://headset-deserve-epinions-fcc.trycloudflare.com
- 임시 주소라 터널을 다시 띄우면 바뀐다. 다시 띄우기: tools/n1_up.py(방·웹·터널 4개를 한 번에). 끄기: `kill 55882 55883 59424 59425`.
- 웹 빌드(build/web)는 ?room= 커밋 뒤에 tools/export_web.sh로 다시 내보냈다(빌드는 git 제외).
- 한계: 맥 쪽 확인은 폰 확인을 대신하지 않는다. 폰 Safari 확인은 아직 안 됐다.
- 참고: 방장 자리가 '서버'라는 닉네임으로 하나 차지된다(현재 코드는 방장이 플레이어, n2가 바꾼다).

## 확인할 것

폰(Safari)에서 아래 주소를 열어 서버 방에 들어가 보세요. 이 맥이 켜져 있고 위 프로세스 4개가 살아 있어야 합니다. 와이파이 말고 LTE로도 한 번 해 보면 공개 터널이 맞는지 알 수 있어요.

- [ ] 폰 Safari에서 https://naval-computer-infections-note.trycloudflare.com/?room=wss://headset-deserve-epinions-fcc.trycloudflare.com 이 열리고, 닉네임을 넣으면 대기실이 뜬다
- [ ] 대기실에 내 닉네임이 보이고 방장 '서버' 옆에 자리가 잡힌다
- [ ] 맥에서 `tail /tmp/n1/room.log`에 SEATED … 내 닉네임이 찍힌다

