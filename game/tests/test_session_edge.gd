extends SceneTree
## 세션이 기대는 엔진 모서리 경우 (P2). 실행:
## engine/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/test_session_edge.gd

const Rules := preload("res://rules/rules.gd")
var fails := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		print("FAIL ", what)

func _init() -> void:
	# 한장! 창이 열린 채 창을 연 사람이 나간다 -> 창이 닫히고 차례가 이어진다
	var r := Rules.new()
	r.setup(3, 5)
	r.discard = [r.make_card(0, "num", 5)]
	r.cur_color = 0
	r.hands[0] = [r.make_card(0, "num", 1), r.make_card(0, "num", 2)]
	r.turn = 0
	check(r.play(0, 0).ok and r.phase == "hanjang", "한장! 창 열림")
	r.leave(0)
	check(r.phase == "pick" and r.hj_seat == -1 and r.turn == 1, "창을 연 사람이 나가면 창이 닫히고 다음 사람 차례")
	check(not r.close_hanjang().ok, "닫힌 창에 close_hanjang은 거절")
	# 2인 와일드+4: 같은 요청을 두 번 보내도 두 번째는 상태를 바꾸지 않는다
	var g := Rules.new()
	g.setup(2, 9)
	g.discard = [g.make_card(1, "num", 3)]
	g.cur_color = 1
	g.hands[0] = [g.make_card(-1, "wild4"), g.make_card(0, "num", 4), g.make_card(0, "num", 6)]
	g.turn = 0
	check(g.play(0, 0, 2).ok, "와일드+4 색 지정")
	var before: int = g.hands[1].size()
	var turn_before: int = g.turn
	var again := g.play(0, 0, 2)
	check(g.turn == turn_before and g.hands[1].size() == before and (not again.ok or g.phase != "color"), "2인 와일드+4 중복 요청은 상태를 더 바꾸지 않는다")
	check(g.hands[1].size() == 11 and g.turn == 0, "2인: 상대 4장 받고 내가 다시")
	# setup 전 snapshot_for 는 부르지 않는다 (세션은 engine 이 없으면 보내지 않음)
	var e := Rules.new()
	check(e.n == 0 and e.discard.is_empty(), "setup 전 엔진은 비어 있다 -> 세션은 engine 생성 뒤에만 snapshot_for 호출")
	print("SESSION_EDGE_", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
