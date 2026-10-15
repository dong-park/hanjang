# relay — 한장! 앱 마무리 → 모바일 웹 크로스플랫폼
갱신: 2026-10-15 18:50 KST · 이전 스레드: 01a13e1a-2590-70f1-a2b9-ba962aeb53b8 · 작업 디렉터리: /Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/godot-multi · 브랜치: master

## 목표

한장!(4인 원카드, Godot 4.7.2) 맥 앱 버전을 마무리하고, 같은 게임을 휴대폰 브라우저에서도 하게 만든다. 맥 앱과 모바일 웹이 같은 방에서 같이 할 수 있어야 한다(크로스플랫폼).

## 끝난 것

- 티켓 spec/hanjang (DAG 8노드, rows 형식, 보드 http://127.0.0.1:8790/w/godot-multi/board/). n1~n7 끝남, 사람 확인 통과.
  - n1 규칙 엔진 8c6529d · n2 픽셀 룩 4b89b48 · n3 대기실 734ac87 · n4 방장 세션 4bd131b · n5 판 화면 5b7846e·ef75ac5 · n6 연출 4b582a3 · n7 연결·결과·끊김 a04d131·2ff012a·9a57a05
- 렌더러를 gl_compatibility로 바꿈 209c435 (Forward+ 수직 동기화에서 프레임이 멈췄다). 웹 내보내기도 이 렌더러가 필요하다.
- 결정 D1~D9 모두 닫힘(rows/D*.json). 차례 20초, 표준 108장, +4 도전 없음, 카드·화면은 픽셀 PNG, 효과음 없음, 한장! 판정 중 차례 멈춤, 결과는 방장이 고름.

## 남은 것

1. **웨이브 9(n8 4인 실경로 확인) 마무리.** 웨이브 스레드 01a13ef2-4795-77a3-a3f2-1e3d9ab2b371이 돌고 있다(잠금 spec/hanjang/.wave). 첫 동작: wait_threads(timeoutMs 0)로 상태를 보고, 끝났으면 spec/hanjang/wave-*.md 최신 보고서를 읽는다. 이어서 go 스킬 「spec이 DAG면」 절차대로 보드 입력(spec-board apply)을 반영한다. n8은 사람이 네 창 중 하나로 직접 하고 14장면 비교 HTML을 보는 확인 대기로 끝날 것이다. 통과하면 spec.md 머리 표 상태를 끝남으로 고친다.
2. **이 스레드에 감시 하트비트를 다시 건다.** 이전 스레드의 "한장! 웨이브 감시" 자동화는 relay하면서 지웠다. 같은 내용(10분마다 잠금 스레드·보드 pending 확인, 변화 없으면 조용히)을 이 스레드에 automation_update heartbeat로 건다.
3. **모바일 웹 버전 spec.** 새 티켓 spec/hanjang-web(rows 형식, ID 머리 HW, 상위 없음 또는 hanjang). spec 스킬(~/agent-env/skills/spec/SKILL.md)대로 spec-writer 서브에이전트에게 맡긴다. 첫 동작: 아래 「확인할 것」을 브리프의 "정하지 않음"에 넣는다. 사용자 문장: "앱버전은 된거고 모바일 웹 버전으로도 크로스플랫폼화 할거야."
4. spec 동의 뒤 DAG로 쪼개 go 스킬로 웨이브를 돌린다.

## 정한 결정

- 작업 방식은 spec → DAG → 웨이브 스레드(wave 스킬) → 노드마다 사람 확인(보드). 사람이 정할 선택은 채팅이 아니라 보드 결정 행(spec-board node block)으로 올린다.
- 웨이브 스레드는 projectless로 열고, 모델은 pick_model.py로 정한다(지금까지 claude-sonnet-5-5). 첫 메시지에 "보드 댓글 첨부 cm-*는 지우지 않는다", "헤드리스 시험은 하나씩 차례로"를 꼭 넣는다 — 둘 다 실제로 사고가 났다.
- 리뷰가 다음 노드로 넘긴 일은 메인이 그 노드 브리프 구현 메모에 옮겨 적는다. runner는 브리프만 읽는다.
- 사용자는 화면 품질에 민감하다. 캡처는 연출 중간이 아니라 뜻이 읽히는 프레임으로, 스토리보드와 나란히 보인다.

## 막힌 점·주의 (웹 버전에서 확인할 것 — 아직 조사 안 함, 모두 미확인)

- 지금 네트워크는 ENetMultiplayerPeer(UDP, 포트 7777)다. 브라우저는 ENet을 못 쓴다. WebSocketMultiplayerPeer(또는 WebRTC)로 바꿔야 하고, 앱과 웹이 같이 하려면 앱도 같은 전송을 써야 한다.
- 브라우저는 서버를 열 수 없다. 방장은 맥 앱(또는 따로 도는 헤드리스 서버)만 할 수 있다. 휴대폰은 참가만 할 수 있는지가 범위 결정이다.
- 웹 빌드를 휴대폰에 어떻게 내려줄지(같은 와이파이의 맥이 정적 파일을 서빙 vs 외부 호스팅). HTTPS 페이지에서는 ws:// 연결이 막힌다(혼합 콘텐츠).
- Godot 4 웹 내보내기의 스레드 사용 여부(COOP/COEP 헤더 필요)와 iOS Safari 호환. 내보내기 템플릿 설치가 필요하다(engine/는 gitignore).
- 화면은 1152×648 가로 고정이다. 휴대폰 세로·가로, 터치 크기(카드 탭, 위로 끌기), 화면 키보드(닉네임·주소 입력)를 정해야 한다.
- spec/hanjang/n8-verify.md에 커밋 안 된 변경이 있다 — 웨이브 9가 쓰는 중이다. 손대지 않는다.

## 다시 읽을 파일

- /Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/godot-multi/spec/hanjang/spec.md
- /Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/godot-multi/game/net/room.gd
- /Users/donghwan/Documents/Codex/2026-10-15/new-chat/outputs/godot-multi/game/net/session.gd
- ~/agent-env/skills/go/SKILL.md
- ~/agent-env/skills/spec/SKILL.md
