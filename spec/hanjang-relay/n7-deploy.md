# n7-deploy — 맥에서 launchd 서비스와 임시 터널로 관리 서비스가 뜬다

> 자기완결 브리프. runner는 상위 spec + 이 파일만 본다. 진행 메모는 이 파일에만 쓴다. `**상태**:` 줄은 손으로 고치지 않는다 — 멈추면 `spec-board node block`, 사람 확인이 필요하면 `spec-board node review`.

**agent**: runner
**id**: HR-7
**상위**: spec/hanjang-relay/spec.md
**deps**: n3
**상태**: 아직 안 함
**담당 행**: T15, T18
**사람 확인**: 필요

## 문제

- 서비스를 이 맥에서 항상 띄우고 밖에서 닿게 하는 방법이 없다. 이 맥이 서버(D2=C)이고 주소는 임시 터널(D3=C)이다.

## 목표

맥에서 launchd 서비스와 임시 터널로 관리 서비스가 뜬다

## 작업

1. 관리 서비스를 launchd(LaunchAgent plist) 또는 시작 스크립트로 띄우고 죽으면 다시 뜨게 한다.
2. cloudflared 임시 터널(trycloudflare)을 실행하는 스크립트를 만들고 주소를 출력한다.
3. 스크립트를 두 번 돌려도 같은 결과(멱등)다.
4. 서비스를 재시작하면 접속자 화면에 「서버가 다시 시작했어요」가 뜨고 방은 사라지며 10초 안에 새 방을 받는다(T15).
5. 로그인 뒤 자동 시작은 launchctl list로 확인한다. T18의 systemd 문구는 launchd로 읽는다.

## 완료 기준

- [ ] 스크립트 한 번으로 서비스와 터널이 뜨고 wss 주소로 대기실이 열린다
- [ ] 재실행해도 같은 결과
- [ ] 재시작 시나리오 문구 확인
- [ ] launchctl list에 서비스가 있다

## 구현 메모

- 임시 주소는 실행마다 바뀐다. 이름 있는 터널과 도메인은 나중 결정이다(여기서 하지 않음).
- 맥이 잠자기에 들어가면 서버가 선다. caffeinate나 에너지 설정을 확인해 적는다.
- launchd 설정은 사용자 LaunchAgents를 쓰고 sudo가 필요한 일은 하지 않는다.
- 헤드리스 시험은 /tmp/hanjang-headless.lock을 잡고 하나씩 차례로 돌린다(동시 실행 금지).
- 커밋은 파일을 지정해 add한다(git add -A·. 금지). push 하지 않는다.
- 보드 댓글 첨부 spec/**/evidence/*/cm-* 파일은 지우지 않는다.
- 결정 D1=C(방마다 헤드리스 Godot), D2=C(이 맥이 서버), D3=C(trycloudflare 임시 주소), D4~D8=A는 닫혔다.
