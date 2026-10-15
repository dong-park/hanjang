extends SceneTree
## 손가락 카드 내기 시험(D6=A). 실행:
## engine/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/test_touch.gd
## 손가락은 마우스 이벤트로 오되 device == DEVICE_ID_EMULATION 이다.

const LocalScene := preload("res://screens/table_local.tscn")

var fails := 0
var sv: SubViewport


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		print("FAIL ", what)


func finger(pos: Vector2, drag_to := Vector2.ZERO) -> void:
	var ev := InputEventMouseButton.new()
	ev.device = InputEvent.DEVICE_ID_EMULATION
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = true
	sv.push_input(ev)
	var end := pos
	if drag_to != Vector2.ZERO:
		var mv := InputEventMouseMotion.new()
		mv.device = InputEvent.DEVICE_ID_EMULATION
		mv.position = drag_to
		mv.global_position = drag_to
		sv.push_input(mv)
		end = drag_to
	var up := InputEventMouseButton.new()
	up.device = InputEvent.DEVICE_ID_EMULATION
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = end
	up.global_position = end
	up.pressed = false
	sv.push_input(up)


func mouse(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = pos
		ev.global_position = pos
		ev.pressed = pressed
		sv.push_input(ev)


func _init() -> void:
	await process_frame
	sv = SubViewport.new()
	sv.size = Vector2i(1152, 648)
	root.add_child(sv)
	var drv = LocalScene.instantiate()
	sv.add_child(drv)
	await process_frame
	await process_frame
	var table = drv.table
	drv.set_process(false)
	var rules = drv.rules
	drv.bot_delay = 99.0
	# 더미 빨강 7. 패: 빨강3, 노랑8(못 냄), 빨강5, 파랑7
	var h := [rules.make_card(0, "num", 3), rules.make_card(1, "num", 8), rules.make_card(0, "num", 5), rules.make_card(3, "num", 7)]
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[0] = h
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await create_timer(1.5).timeout   # 배분·더미 날기가 끝나야 가운데 카드가 덮이지 않는다
	var hv = table.hand_view
	var sent := []
	table.action_requested.connect(func(a): sent.append(a))
	var a: Dictionary = h[0]
	var b: Dictionary = h[2]
	var dark: Dictionary = h[1]
	var pa: Vector2 = hv.views[a.id].get_global_rect().get_center()
	var pb: Vector2 = hv.views[b.id].get_global_rect().get_center()
	var pd: Vector2 = hv.views[dark.id].get_global_rect().get_center()

	finger(pa)
	await process_frame
	check(sent.is_empty() and hv.selected == a.id and hv.views[a.id].lift == 2, "손가락 한 번 누르면 카드만 올라간다(내지 않는다)")
	finger(pb)
	await process_frame
	check(sent.is_empty() and hv.selected == b.id and hv.views[a.id].lift == 1 and hv.views[b.id].lift == 2, "다른 카드를 누르면 이전 카드가 내려가고 새 카드가 올라간다")
	finger(Vector2(30, 300))
	await process_frame
	check(sent.is_empty() and hv.selected == -1 and hv.views[b.id].lift == 1, "빈 곳을 누르면 내려가고 아무것도 내지 않는다")
	finger(pa)
	await process_frame
	finger(pd)
	await process_frame
	check(sent.is_empty() and hv.selected == -1 and hv.views[a.id].lift == 1, "낼 수 없는 카드를 누르면 올라가지 않고 올린 카드도 내려간다")
	check(hv.views[dark.id].lift == 0, "낼 수 없는 카드는 올라가 있지 않다")
	finger(pa)
	await process_frame
	finger(pa)
	await process_frame
	check(sent.size() == 1 and sent[0].type == "play" and sent[0].id == a.id, "올라간 같은 카드를 한 번 더 누르면 낸다")
	check(rules.top().id == a.id, "엔진 더미 맨 위가 낸 카드")

	# 끌어 올리기도 된다 + 마우스는 한 번에 낸다
	await create_timer(0.8).timeout
	sent.clear()
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[0] = [rules.make_card(0, "num", 3), rules.make_card(0, "num", 4), rules.make_card(1, "num", 1)]
	rules.turn = 0
	rules.phase = "pick"
	table.unlock()
	drv.push()
	await process_frame
	var c: Dictionary = rules.hands[0][0]
	var pc: Vector2 = hv.views[c.id].get_global_rect().get_center()
	finger(pc, pc + Vector2(0, -100))
	await process_frame
	check(sent.size() == 1 and sent[0].id == c.id and hv.selected == -1, "손가락으로 위로 끌면 바로 낸다")
	await create_timer(0.8).timeout
	sent.clear()
	table.unlock()
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[0] = [rules.make_card(0, "num", 3), rules.make_card(0, "num", 4), rules.make_card(1, "num", 1)]
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await process_frame
	var m: Dictionary = rules.hands[0][0]
	mouse(hv.views[m.id].get_global_rect().get_center())
	await process_frame
	check(sent.size() == 1 and sent[0].id == m.id and hv.selected == -1, "마우스는 한 번 누르면 바로 낸다(앱 동작 그대로)")
	print("touch fails=", fails)
	quit(1 if fails > 0 else 0)
