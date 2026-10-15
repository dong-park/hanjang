extends SceneTree
## 장면 13·14 캡처. 창을 띄워야 한다(헤드리스 불가). 실행:
## engine/Godot.app/Contents/MacOS/Godot --path game --script res://tests/capture_wire.gd -- --out=/절대/경로

const LocalScene := preload("res://screens/table_local.tscn")
const ResultScene := preload("res://screens/result.tscn")
var out := "/tmp"


func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if root.get_node_or_null("Session") == null:  ## --script 실행에는 자동 로드가 없다: 가짜 노드를 세운다
		for pair in [["Session", "extends Node\nvar seats = []\nvar last_snap = {}\n"], ["Room", "extends Node\nfunc is_host():\n\treturn true\nfunc replay():\n\tpass\nfunc back_to_lobby():\n\tpass\n"]]:
			var sc := GDScript.new()
			sc.source_code = pair[1]
			sc.reload()
			var n := Node.new()
			n.name = pair[0]
			n.set_script(sc)
			root.add_child(n)
	var drv = LocalScene.instantiate()
	root.add_child(drv)
	drv.set_process(false)
	await process_frame
	var r = drv.rules
	var t = drv.table
	r.hands[1].resize(6)
	r.hands[2].resize(5)
	r.hands[3].resize(4)
	drv.push()
	await process_frame

	# 14: 체리(자리 3)가 카드 4장을 든 채 나갔다
	t.fx.disconnect_fx(3, 4, "체리")
	r.leave(3)
	drv.push()
	await create_timer(0.3).timeout
	await shot("14-disconnect")
	await create_timer(2.8).timeout

	# 13: 결과 화면 (방장 쪽). 1등 하늘, 2등 민트, 체리는 나감
	var names := ["하늘", "나", "민트", "체리"]
	var seats: Array = []
	for i in 4:
		seats.append({"peer": i + 1, "name": names[i], "face": i})
	var session = root.get_node("Session")
	session.seats = seats
	r.hands[0] = r.hands[1].slice(0, 2)
	r.hands[1].resize(3)
	r.hands[2].resize(1)
	r.hands[0] = []
	r.winner = 2
	r.phase = "done"
	session.last_snap = r.snapshot_for(0)
	drv.queue_free()
	await process_frame
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/bg_tile.png")
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.theme = load("res://ui/theme.tres")
	root.add_child(host)
	host.add_child(bg)
	var res = ResultScene.instantiate()
	res.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(res)
	await shot("13-result-host")
	quit(0)
