extends SceneTree
## 연출 시험. 실행:
## engine/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/test_fx.gd

const Rules := preload("res://rules/rules.gd")
const FxEvents := preload("res://ui/fx/fx_events.gd")
const FxTiming := preload("res://ui/fx/fx_timing.gd")
const LocalScene := preload("res://screens/table_local.tscn")

var fails := 0
var sv: SubViewport


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		fails += 1
		print("FAIL ", what)


func fresh(count: int, seed_value: int) -> Rules:
	var r := Rules.new()
	r.setup(count, seed_value)
	r.discard = [r.make_card(0, "num", 7)]
	r.cur_color = 0
	r.turn = 1
	r.phase = "pick"
	return r


func events_after(r: Rules, seat: int, card: Dictionary, color := -1) -> Array:
	r.hands[seat].push_front(card)
	var before := r.snapshot_for(0)
	r.play(seat, 0, color)
	var mid := r.snapshot_for(0)
	if r.phase == "color":
		r.choose_color(seat, 2)
		return FxEvents.derive(mid, r.snapshot_for(0))
	return FxEvents.derive(before, mid)


func find_text(table, needle: String) -> bool:
	for c in table.fx.get_children():
		var l = c if c is Label else (c.get_child(0) if c is PanelContainer and c.get_child_count() > 0 else null)
		if l is Label and l.text.find(needle) >= 0:
			return true
	return false


func wait_fx(table, limit := 6.0) -> void:
	var t := 0.0
	while table.fx.active > 0 and t < limit:
		await create_timer(0.1).timeout
		t += 0.1


func _init() -> void:
	# --- 이벤트 고르기: 화면 없이 ---
	var r := fresh(4, 5)
	var ev := events_after(r, 1, r.make_card(0, "draw2"))
	check(ev.size() == 1 and ev[0].type == "attack" and ev[0].by == 1 and ev[0].victim == 2 and ev[0].amount == 2, "+2: 다음 사람이 2장 받는 공격")
	r = fresh(4, 5)
	ev = events_after(r, 1, r.make_card(-1, "wild4"), 2)
	check(ev.size() == 1 and ev[0].type == "attack" and ev[0].victim == 2 and ev[0].amount == 4, "와일드+4: 색을 고른 뒤 4장 공격")
	r = fresh(4, 5)
	r.hands[1].push_front(r.make_card(-1, "wild4"))
	var b := r.snapshot_for(0)
	r.play(1, 0)
	check(FxEvents.derive(b, r.snapshot_for(0)).is_empty(), "와일드+4: 색 고르기 전에는 공격 연출 없음")
	r = fresh(4, 5)
	ev = events_after(r, 1, r.make_card(0, "skip"))
	check(ev.size() == 1 and ev[0].type == "skip" and ev[0].seat == 2, "스킵: 건너뛴 사람은 다음 자리")
	r = fresh(4, 5)
	r.dir = -1
	r.turn = 2
	ev = events_after(r, 2, r.make_card(0, "skip"))
	check(ev.size() == 1 and ev[0].seat == 1, "반시계에서 스킵은 반대쪽 자리를 건너뜀")
	r = fresh(4, 5)
	ev = events_after(r, 1, r.make_card(0, "rev"))
	check(ev.size() == 1 and ev[0].type == "reverse" and ev[0].clockwise == false, "리버스: 방향이 반대로")
	r = fresh(2, 5)
	r.turn = 1
	ev = events_after(r, 1, r.make_card(0, "rev"))
	check(ev.size() == 1 and ev[0].type == "skip" and ev[0].seat == 0, "2명 리버스는 스킵 연출")
	r = fresh(4, 5)
	ev = events_after(r, 1, r.make_card(0, "num", 3))
	check(ev.is_empty(), "숫자 카드는 연출 없음")
	check(FxEvents.derive({}, r.snapshot_for(0)).is_empty(), "앞 스냅샷이 없으면 연출 없음")

	# --- 판 화면 위에서 ---
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
	var sent := []
	table.action_requested.connect(func(a): sent.append(a))

	# 장면 09: 내가 +2를 맞는다
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[0] = [rules.make_card(0, "num", 3), rules.make_card(1, "num", 8), rules.make_card(2, "num", 4)]
	rules.hands[3] = [rules.make_card(0, "draw2"), rules.make_card(1, "num", 1), rules.make_card(1, "num", 2)]
	rules.turn = 3
	rules.phase = "pick"
	drv.push()
	await create_timer(0.6).timeout
	rules.play(3, 0)
	drv.push()
	await process_frame
	await process_frame
	check(find_text(table, "+2") and find_text(table, "공격"), "+2를 맞으면 큰 +2와 공격 문구")
	check(table.fx.active > 0, "연출이 돌고 있다")
	check(table.snap.counts[0] == 5 and table.hand_view.views.size() == 5, "연출 중에도 화면 상태는 새 상태(내 패 5장)")
	rules.hands[1].append(rules.make_card(3, "num", 9))
	drv.push()
	await process_frame
	check(table.snap.counts[1] == rules.hands[1].size() and table.snap.counts[0] == 5, "연출 중 다음 상태가 오면 화면이 그 상태를 따른다")
	await wait_fx(table)
	check(table.fx.active == 0 and table.fx.get_child_count() == 0, "연출이 끝나면 층이 비어 있다")

	# 장면 10: 스킵 도장, 리버스 고리
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[1] = [rules.make_card(0, "skip"), rules.make_card(0, "rev"), rules.make_card(1, "num", 1), rules.make_card(2, "num", 4)]
	rules.turn = 1
	rules.phase = "pick"
	drv.push()
	await create_timer(0.6).timeout
	rules.play(1, 0)
	drv.push()
	await process_frame
	check(find_text(table, "건너뜀"), "스킵: 건너뜀! 문구")
	await wait_fx(table)
	rules.turn = 1
	rules.phase = "pick"
	var rev_idx := 0
	for i in rules.hands[1].size():
		if rules.hands[1][i].kind == "rev":
			rev_idx = i
	rules.play(1, rev_idx)
	drv.push()
	await process_frame
	await process_frame
	check(find_text(table, "반대로") and table._ring.color == table.fx.YELLOW, "리버스: 반대로! 문구와 노란 고리")
	check(table._ring.clockwise == (rules.dir > 0), "리버스: 화살표 방향이 판 상태와 같다")
	await wait_fx(table)
	check(table._ring.color.is_equal_approx(table.fx.RING_BLUE), "리버스: 고리가 원래 색으로 돌아온다")

	# 장면 12: 내가 낸 사람 — 한장! 버튼
	sent.clear()
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[0] = [rules.make_card(0, "num", 3), rules.make_card(1, "num", 8)]
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await create_timer(0.6).timeout
	rules.play(0, 0)
	drv.push()
	await process_frame
	check(rules.phase == "hanjang" and table.hj_ui.mode == "call" and table.hj_ui.btn.visible and not table.hj_ui.panel.visible, "내가 1장 남기면 내 화면에 한장! 버튼")
	check(table.hj_ui.bar.max_value == 3.0 and table.hj_ui.bar.visible, "3초 바")
	table.hj_ui.btn.pressed.emit()
	await process_frame
	check(sent.size() == 1 and sent[0].type == "hanjang", "버튼은 hanjang 행동 하나를 낸다")
	check(rules.phase == "pick" and rules.hj_seat == -1, "엔진이 외침을 받는다")
	check(not table.hj_ui.btn.visible and find_text(table, "1장 남음"), "외친 뒤 버튼이 사라지고 1장 남음! 문구")
	await wait_fx(table)

	# 장면 12: 남이 낸 사람 — 잡았다!
	sent.clear()
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.hands[2] = [rules.make_card(0, "num", 3), rules.make_card(1, "num", 8)]
	rules.turn = 2
	rules.phase = "pick"
	drv.push()
	await create_timer(0.6).timeout
	rules.play(2, 0)
	drv.push()
	await process_frame
	check(table.hj_ui.mode == "catch" and table.hj_ui.btn.text == "잡았다!" and table.hj_ui.panel.visible, "남이 1장 남기면 잡았다! 버튼")
	check(table.hj_ui.label.text.find(table.names[2]) >= 0 and table.hj_ui.label.text.find("1장 남음") >= 0, "누가 1장 남았는지 보인다")
	table.hj_ui.btn.pressed.emit()
	await process_frame
	check(sent.size() == 1 and sent[0].type == "catch", "버튼은 catch 행동 하나를 낸다")
	check(rules.hands[2].size() == 3 and table.snap.counts[2] == 3, "잡힌 사람은 2장을 받아 3장")
	check(find_text(table, "잡았다") and table.fx.active > 0, "모든 화면에 잡았다 문구와 카드 날기")
	table.hj_ui.btn.pressed.emit()
	await process_frame
	check(rules.hands[2].size() == 3, "창이 닫힌 뒤 늦게 누른 사람에게는 아무 일도 없다")
	await wait_fx(table)

	# 한장! 창이 시간으로 닫히면 버튼이 사라진다
	rules.hands[0] = [rules.make_card(0, "num", 3), rules.make_card(1, "num", 8)]
	rules.discard = [rules.make_card(0, "num", 7)]
	rules.cur_color = 0
	rules.turn = 0
	rules.phase = "pick"
	drv.push()
	await create_timer(0.6).timeout
	rules.play(0, 0)
	drv.push()
	rules.close_hanjang()
	drv.push()
	await process_frame
	check(not table.hj_ui.btn.visible and table.hj_ui.mode == "", "창이 시간으로 닫히면 버튼이 사라진다")

	# 장면 04: 나눠 주기
	drv.set_process(false)
	rules.setup(4, 9)
	table.start_deal()
	drv.push()
	await process_frame
	check(table._dealing and table.hand_view.views.size() == 0 and not table._discard_cv.visible, "나눠 주는 동안 내 패는 비고 첫 카드는 덮여 있다")
	var ordered := true
	for _i in 6:
		await create_timer(0.25).timeout
		var d: Array = table._dealt
		if not table._dealing:
			break
		# 방장(자리0)부터 시계 방향이라 앞 자리가 뒷 자리보다 많거나 같고 차이는 1을 넘지 않는다
		if not (d[0] >= d[1] and d[1] >= d[2] and d[2] >= d[3] and d[0] - d[3] <= 1):
			ordered = false
	check(ordered, "카드는 방장부터 시계 방향으로 한 장씩")
	rules.hands[1].append(rules.make_card(3, "num", 9))
	drv.push()
	await wait_fx(table)
	await process_frame
	check(not table._dealing and table.hand_view.views.size() == 7 and table._discard_cv.visible, "다 나눈 뒤 7장씩 쌓이고 첫 카드가 보인다")
	check(table.snap.counts[1] == 8 and table.snap.counts == rules.snapshot_for(0).counts, "나눠 주는 중 온 새 상태를 끝에 따른다")

	print("FX_TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails else 0)
