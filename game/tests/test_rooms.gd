extends SceneTree
## 방 고르기 화면 시험(n6). tests/test_rooms.sh 가 관리 서비스와 공개 방 1개·비공개 방 1개를 먼저 열고 이 스크립트를 돌린다.
## 인자: -- --relay=http://127.0.0.1:포트 --private=코드 --shot=폴더(선택)

var fails := 0
var main_node: Node
var R: Node


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func scr() -> Node:
	return main_node._current


func name_of() -> String:
	return scr().scene_file_path.get_file().get_basename()


func wait_for(cond: Callable, sec := 8.0) -> bool:
	var t := 0.0
	while t < sec:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func shot(label: String, dir: String) -> void:
	if dir == "":
		return
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, label])


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var opts := {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	R = root.get_node("Room")
	var priv: String = opts.private
	var dir: String = opts.get("shot", "")
	R.relay_base = opts.relay
	R.my_name = "테스터"
	R.token_path = "/tmp/hanjang-test-rooms-tokens.json"
	main_node = load("res://main.tscn").instantiate()
	root.add_child(main_node)
	await create_timer(0.5).timeout
	main_node.show_rooms(false)
	var s = scr()
	await wait_for(func(): return s._listed)
	check(s._listed, "방 목록을 받았다")
	await create_timer(0.3).timeout
	var rows: int = s._list_box.get_child_count()
	check(rows == 1 and s._list_box.get_child(0) is HBoxContainer, "공개 방 1개만 목록에 있다 (비공개 제외)")
	var row: HBoxContainer = s._list_box.get_child(0)
	check((row.get_child(1) as Label).text == "0/4 · 대기 중", "인원과 대기 중이 보인다: " + (row.get_child(1) as Label).text)
	check(not (row.get_child(2) as Button).disabled, "대기 방은 입장 단추가 눌린다")
	await shot("rooms-list", dir)
	s._code_edit.text = "0000"
	s._on_enter_code()
	await wait_for(func(): return s._status.text != "" and s._status.text != "들어가는 중 · · ·")
	check(s._status.text == "방을 못 찾았어요", "틀린 코드: " + s._status.text)
	await shot("fail-notfound", dir)
	s._code_edit.text = "12"
	s._on_enter_code()
	check(s._status.text == "4자리 코드를 적어 주세요", "짧은 코드: " + s._status.text)
	s._busy = false
	s._code_edit.text = priv
	s._on_enter_code()
	check(await wait_for(func(): return name_of() == "lobby"), "코드로 비공개 방에 들어가 대기실이 열렸다")
	check(R.via_relay and R.room_label() == "방 코드 " + priv, "대기실 표시: " + R.room_label())
	await shot("lobby-private", dir)
	R.leave()
	main_node.show_rooms(false)
	s = scr()
	await wait_for(func(): return s._listed)
	s._name_edit.text = "시험방"
	s._on_create()
	check(await wait_for(func(): return s._made != null), "방 만들기 뒤 코드 카드가 떴다")
	check(s._made_code.length() == 4, "4자리 코드: " + s._made_code)
	await shot("created", dir)
	s._enter_made()
	check(await wait_for(func(): return name_of() == "lobby"), "만든 방으로 들어가 대기실이 열렸다")
	R.leave()
	main_node.show_rooms(false)
	s = scr()
	await wait_for(func(): return s._listed)
	await wait_for(func(): return s._list_box.get_child_count() == 2 and s._list_box.get_child(0) is HBoxContainer)
	check(s._list_box.get_child_count() == 2, "만든 공개 방이 목록에 늘었다")
	print("ROOMS_TEST_FAILS ", fails)
	quit(1 if fails > 0 else 0)
