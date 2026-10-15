extends SceneTree
## 판 화면 시험. 실행:
## engine/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/test_table.gd

const Rules := preload("res://rules/rules.gd")
const CardMap := preload("res://ui/card_map.gd")
const LocalScene := preload("res://screens/table_local.tscn")

var fails := 0
var sv: SubViewport


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		print("FAIL ", what)


func click(pos: Vector2, drag_to := Vector2.ZERO) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = true
	sv.push_input(ev)
	if drag_to != Vector2.ZERO:
		var mv := InputEventMouseMotion.new()
		mv.position = drag_to
		mv.global_position = drag_to
		sv.push_input(mv)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = drag_to if drag_to != Vector2.ZERO else pos
	up.global_position = up.position
	up.pressed = false
	sv.push_input(up)


func _init() -> void:
	# 카드 변환과 낼 수 있는 판정이 엔진과 같다
	var r := Rules.new()
	r.setup(2, 3)
	check(CardMap.view_value(r.make_card(1, "draw2")) == "plus2", "draw2 -> plus2")
	check(CardMap.view_value(r.make_card(2, "rev")) == "reverse", "rev -> reverse")
	check(CardMap.view_color(r.make_card(-1, "wild4")) == "wild", "wild color")
	check(CardMap.view_value(r.make_card(3, "num", 7)) == "7", "num value")

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

	# 엔진과 판정 일치: 같은 판 상태에서 모든 카드 종류를 비교
	var mismatch := 0
	for top_c in [rules.make_card(0, "num", 7), rules.make_card(1, "skip"), rules.make_card(2, "draw2"), rules.make_card(3, "rev"), rules.make_card(0, "num", 0)]:
		for col in 4:
			rules.discard = [top_c]
			rules.cur_color = col
			var s: Dictionary = rules.snapshot_for(0)
			for c in rules.build_deck():
				if table.is_playable(c, s) != rules.can_play(c):
					mismatch += 1
	check(mismatch == 0, "화면 판정이 엔진 can_play와 같다")

	# 판 고정: 더미 빨강 7, 내 패 = 빨강3, 노랑8, 초록스킵, 파랑5, 빨강7(파랑), 노랑+2, 와일드
	var h := [rules.make_card(0, "num", 3), rules.make_card(1, "num", 8), rules.make_card(2, "skip"),
		rules.make_card(3, "num", 5), rules.make_card(3, "num", 7), rules.make_card(1, "draw2"), rules.make_card(-1, "wild")]
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[0] = h
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await process_frame
	var hv = table.hand_view
	var raised := 0
	var dark := 0
	for card in h:
		var cv = hv.views[card.id]
		if cv.lift == 1:
			raised += 1
		if cv.dimmed:
			dark += 1
	check(raised == 3 and dark == 4, "빨강3, 7, 와일드만 솟고 나머지 어둡다 (솟음 %d 어둠 %d)" % [raised, dark])
	check(table._bar.visible and table.btn_draw.disabled == false, "내 차례에 시간 바와 뽑기 버튼")

	# 어두운 카드: 누르기와 위로 끌기에 행동이 나가지 않는다
	var sent := []
	table.action_requested.connect(func(a): sent.append(a))
	var dark_card: Dictionary = h[1]
	var p: Vector2 = hv.views[dark_card.id].get_global_rect().get_center()
	click(p)
	click(p, p + Vector2(0, -120))
	await process_frame
	check(sent.is_empty(), "어두운 카드 누르기·끌기에 행동이 없다")
	check(rules.top().num == 7 and rules.turn == 0 and rules.hands[0].size() == 7, "더미·차례·패 그대로")

	# 솟은 카드 누르기 → 행동 하나 → 엔진이 받는다
	var good: Dictionary = h[0]
	click(hv.views[good.id].get_global_rect().get_center())
	await process_frame
	check(sent.size() == 1 and sent[0].type == "play" and sent[0].id == good.id, "솟은 카드 누르면 play 행동")
	check(rules.top().id == good.id, "엔진 더미 맨 위가 낸 카드")
	await create_timer(0.1).timeout
	check(table._flying >= 1, "내 카드가 날아가는 중")
	await create_timer(0.6).timeout
	check(table._flying == 0 and table._discard_cv.visible, "날기 끝나면 더미 카드가 보인다")

	# 위로 끌기로 내기
	sent.clear()
	drv.bot_delay = 99.0
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[0] = [rules.make_card(0, "num", 3), rules.make_card(1, "num", 8), rules.make_card(2, "num", 1)]
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await process_frame
	var up_card: Dictionary = rules.hands[0][0]
	var q: Vector2 = hv.views[up_card.id].get_global_rect().get_center()
	click(q, q + Vector2(0, -100))
	await process_frame
	check(sent.size() == 1 and sent[0].id == up_card.id, "위로 끌면 낸다")

	# 상대 카드: 하늘(자리1) 차례, 내 패는 평평하다
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[1] = [rules.make_card(0, "num", 9), rules.make_card(1, "num", 1), rules.make_card(1, "num", 2)]
	rules.hands[0] = [rules.make_card(2, "num", 4), rules.make_card(3, "num", 2), rules.make_card(3, "num", 6)]
	rules.turn = 1
	rules.phase = "pick"
	drv.push()
	await process_frame
	var all_dark := true
	for id in hv.views:
		var cv = hv.views[id]
		if cv.lift != 0 or not cv.dimmed:
			all_dark = false
	await create_timer(0.6).timeout  # 장면 만들기로 생긴 날기가 끝나길 기다린다
	check(all_dark, "남의 차례에 내 패 전체가 어둡고 솟은 카드가 없다")
	var wait_card: Dictionary = rules.hands[0][0]
	var wp: Vector2 = hv.views[wait_card.id].get_global_rect().get_center()
	var sent_wait := []
	table.action_requested.connect(func(a): sent_wait.append(a))
	click(wp)
	await process_frame
	check(sent_wait.is_empty(), "남의 차례에 내 카드를 눌러도 행동이 없다")
	drv.bot_step()
	await create_timer(0.1).timeout
	check(table._flying >= 1, "상대 카드가 날아온다")
	check(table._discard_cv.visible and table._discard_cv.value == "7" and table._discard_cv.color == "red", "날아오는 동안 버린 더미는 이전 맨 위 카드(빨강 7)")
	check(table._fx.get_child_count() >= 1 and table._fx.get_child(0).position.x < 584.0 - 5.0 or table._fx.get_child(0).position.y < 248.0, "날아오는 카드는 뽑을 더미 쪽이 아닌 낸 사람 자리에서 출발")
	await create_timer(0.6).timeout
	check(table._flying == 0 and table._discard_cv.value == str(rules.top().num), "내려앉은 뒤 버린 더미가 새 카드로 바뀐다")

	# 와일드: 내면 팝업, 파랑을 누르면 모두가 파랑을 본다
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	var w: Dictionary = rules.make_card(-1, "wild")
	rules.hands[0] = [w, rules.make_card(0, "num", 3), rules.make_card(2, "num", 4)]
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await process_frame
	sent.clear()
	click(hv.views[w.id].get_global_rect().get_center())
	await process_frame
	check(table.wild_picker.visible and rules.phase == "color", "와일드를 내면 색 고르기 팝업")
	table.wild_picker.buttons[3].pressed.emit()
	await process_frame
	check(rules.cur_color == 3 and table.snap.color == 3, "파랑이 정해지고 화면에 반영")
	check(not table.wild_picker.visible, "팝업이 닫힌다")
	rules.turn = 0
	rules.phase = "pick"
	rules.hands[0] = [rules.make_card(0, "num", 3), rules.make_card(3, "num", 3), rules.make_card(-1, "wild")]
	drv.push()
	await process_frame
	var up_ids := 0
	for id in hv.views:
		if hv.views[id].lift == 1:
			up_ids += 1
	check(up_ids == 2, "파랑과 와일드만 솟는다")

	# 뽑기: 맞는 카드 → 바로 내기 / 가지기, 안 맞는 카드 → 패에 들어가고 차례 넘김
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	var fit: Dictionary = rules.make_card(0, "num", 2)
	rules.hands[0] = [rules.make_card(1, "num", 8), rules.make_card(2, "num", 4)]
	rules.deck = [fit]
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await process_frame
	table.btn_draw.pressed.emit()
	await process_frame
	check(table.draw_choice.visible and rules.phase == "drawn", "맞는 카드를 뽑으면 바로 내기·가지기")
	table.draw_choice.play_now.emit()
	await process_frame
	check(rules.top().id == fit.id, "바로 내기로 더미에 올라간다")
	await create_timer(0.6).timeout
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	fit = rules.make_card(0, "num", 2)
	rules.hands[0] = [rules.make_card(1, "num", 8), rules.make_card(2, "num", 4)]
	rules.deck = [fit]
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await process_frame
	table.btn_draw.pressed.emit()
	await process_frame
	table.draw_choice.keep.emit()
	await process_frame
	check(rules.hands[0].size() == 3 and rules.turn == 1, "가지기: 패에 들어가고 차례 넘어감")
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	var bad: Dictionary = rules.make_card(2, "num", 4)
	rules.hands[0] = [rules.make_card(1, "num", 8), rules.make_card(2, "num", 5)]
	rules.deck = [bad]
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await process_frame
	table.btn_draw.pressed.emit()
	await process_frame
	check(rules.hands[0].size() == 3 and rules.turn == 1 and not table.draw_choice.visible, "안 맞는 카드: 패에 들어가고 바로 넘어감")

	# 관통: 화면 입력 경로만으로 혼자 한 판을 끝까지
	drv.bot_delay = 0.0
	rules.setup(4, 11)
	drv.push()
	var steps := 0
	while rules.phase != "done" and steps < 4000:
		steps += 1
		await process_frame
		if rules.phase == "hanjang":
			if rules.hj_seat == 0:
				table.hj_ui.btn.pressed.emit()
			else:
				drv.settle_hanjang()
			continue
		if rules.turn != 0:
			drv.bot_step()
			continue
		match rules.phase:
			"pick":
				var chosen := -1
				for id in hv.views:
					if hv.views[id].lift == 1:
						chosen = id
						break
				if chosen >= 0:
					hv.choose(chosen)
				else:
					table.btn_draw.pressed.emit()
			"color":
				table.wild_picker.buttons[0].pressed.emit()
			"drawn":
				table.draw_choice.play_now.emit()
	check(rules.phase == "done", "혼자 한 판이 끝까지 간다 (%d걸음)" % steps)
	check(table._end_label.visible, "끝나면 승자 문구")

	print("TABLE_TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails else 0)

