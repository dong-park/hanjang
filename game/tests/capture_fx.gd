extends SceneTree
## 장면 04·09·10·12 캡처. 창을 띄워야 한다(헤드리스 불가). 실행:
## engine/Godot.app/Contents/MacOS/Godot --path game --script res://tests/capture_fx.gd -- --out=/절대/경로

const LocalScene := preload("res://screens/table_local.tscn")
var out := "/tmp"
var drv
var r
var t


func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func settle() -> void:
	while t.fx.active > 0:
		await create_timer(0.1).timeout


func stage(top_c, color: int, turn: int, phase := "pick") -> void:
	r.discard = [top_c]
	r.cur_color = color
	r.turn = turn
	r.phase = phase
	r.hands[0] = [r.make_card(0, "num", 3), r.make_card(1, "num", 8), r.make_card(2, "skip"), r.make_card(3, "num", 5), r.make_card(0, "num", 7), r.make_card(-1, "wild")]
	r.hands[1].resize(6)
	r.hands[2].resize(6)
	r.hands[3].resize(4)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	drv = LocalScene.instantiate()
	root.add_child(drv)
	drv.set_process(false)
	await process_frame
	r = drv.rules
	t = drv.table

	# 04: 나눠 주기 한가운데
	r.setup(4, 3)
	t.start_deal()
	drv.push()
	await create_timer(0.75).timeout
	await shot("04-deal-flying")
	await settle()
	await create_timer(0.4).timeout
	await shot("04b-deal-done-first-card-flipped")

	# 09: 체리가 +2, 내가 맞는다
	stage(r.make_card(1, "num", 4), 1, 3)
	r.hands[3].push_front(r.make_card(1, "draw2"))
	drv.push()
	await create_timer(0.6).timeout
	r.play(3, 0)
	drv.push()
	await create_timer(0.3).timeout
	await shot("09-attack-plus2")
	await settle()

	# 10: 스킵과 리버스
	stage(r.make_card(3, "num", 4), 3, 2)
	r.hands[2].push_front(r.make_card(3, "skip"))
	drv.push()
	await create_timer(0.6).timeout
	r.play(2, 0)
	drv.push()
	await create_timer(0.45).timeout
	await shot("10a-skip-stamp")
	await settle()
	stage(r.make_card(3, "num", 4), 3, 3)
	r.hands[3].push_front(r.make_card(3, "rev"))
	drv.push()
	await create_timer(0.6).timeout
	r.play(3, 0)
	drv.push()
	await create_timer(0.45).timeout
	await shot("10b-reverse-yellow-ring")
	await settle()

	# 12: 내가 낸 사람 / 남이 낸 사람
	stage(r.make_card(0, "num", 4), 0, 0)
	r.hands[0] = [r.make_card(0, "num", 3), r.make_card(1, "num", 8)]
	drv.push()
	await create_timer(0.6).timeout
	r.play(0, 0)
	drv.push()
	await create_timer(0.8).timeout
	await shot("12a-my-hanjang-button")
	t.hj_ui.btn.pressed.emit()
	await create_timer(0.7).timeout
	await shot("12b-called-one-left")
	await settle()
	stage(r.make_card(0, "num", 4), 0, 3)
	r.hands[3] = [r.make_card(0, "num", 3), r.make_card(1, "num", 8)]
	drv.push()
	await create_timer(0.6).timeout
	r.play(3, 0)
	drv.push()
	await create_timer(0.8).timeout
	await shot("12c-others-catch-button")
	t.hj_ui.btn.pressed.emit()
	await create_timer(0.6).timeout
	await shot("12d-caught-plus2")
	quit()
