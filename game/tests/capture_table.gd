extends SceneTree
## 장면 05·06·07·08·11 캡처. 창을 띄워야 한다(헤드리스 불가). 실행:
## engine/Godot.app/Contents/MacOS/Godot --path game --script res://tests/capture_table.gd -- --out=/절대/경로

const LocalScene := preload("res://screens/table_local.tscn")
var out := "/tmp"


func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func stage(rules, top_c, color: int, hand: Array, turn := 0, phase := "pick") -> void:
	rules.discard = [top_c]
	rules.cur_color = color
	rules.hands[0] = hand
	rules.turn = turn
	rules.phase = phase


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var drv = LocalScene.instantiate()
	root.add_child(drv)
	drv.set_process(false)
	await process_frame
	var r = drv.rules
	var t = drv.table
	r.hands[1].resize(6)
	r.hands[2].resize(5)
	r.hands[3].resize(4)
	var hand := [r.make_card(0, "num", 3), r.make_card(1, "num", 8), r.make_card(2, "skip"),
		r.make_card(3, "num", 5), r.make_card(0, "num", 7), r.make_card(1, "draw2"), r.make_card(-1, "wild")]

	# 05: 내 차례, 빨강 7
	stage(r, r.make_card(0, "num", 7), 0, hand)
	drv.push()
	await shot("05-my-turn")

	# 06: 내 카드가 더미로 날아가는 중
	t.hand_view.choose(hand[4].id)
	await create_timer(0.12).timeout
	await shot("06-play-fly")
	await create_timer(0.5).timeout

	# 07: 하늘 카드가 가운데로 날아오는 중
	stage(r, r.make_card(0, "num", 7), 0, [r.make_card(0, "num", 3), r.make_card(1, "num", 8), r.make_card(2, "skip"), r.make_card(3, "num", 5), r.make_card(1, "draw2")], 1)
	r.hands[1] = [r.make_card(0, "num", 9), r.make_card(1, "num", 1), r.make_card(1, "num", 2), r.make_card(2, "num", 2), r.make_card(3, "num", 2), r.make_card(3, "num", 4)]
	drv.push()
	await create_timer(0.7).timeout
	drv.bot_step()
	await create_timer(0.1).timeout
	await shot("07a-opponent-flying")
	await create_timer(0.7).timeout
	await shot("07b-opponent-landed")

	# 08: 와일드 색 고르기
	stage(r, r.make_card(0, "num", 7), 0, [r.make_card(0, "num", 3), r.make_card(1, "num", 8), r.make_card(2, "skip"), r.make_card(3, "num", 5), r.make_card(1, "draw2")], 0, "color")
	r.pending_wild = r.make_card(-1, "wild")
	r.discard.append(r.pending_wild)
	drv.push()
	await create_timer(0.7).timeout
	await shot("08-wild-picker")

	# 11: 뽑은 카드 바로 내기·가지기
	var blue6 = r.make_card(3, "num", 6)
	stage(r, r.make_card(3, "num", 2), 3, [r.make_card(0, "num", 3), r.make_card(1, "num", 8), r.make_card(0, "num", 9), r.make_card(1, "draw2"), blue6], 0, "drawn")
	r.drawn_idx = 4
	drv.push()
	await create_timer(0.7).timeout
	await shot("11-draw-choice")
	quit()
