extends Node
## 시험용 장면 캡처 (--shots=폴더). 실제 창에서 실제 경로로 돈 판의 장면을 "NN-이름-seatS.png" 로 저장한다. 장면당 창마다 한 번만.
## main.gd 가 --shots 가 있을 때만 붙인다. 판 규칙과 화면 코드는 건드리지 않고 신호만 듣는다.

var dir := ""
var main
var _done := {}
var _prev := {}


func setup(p_main, p_dir: String) -> void:
	main = p_main
	dir = p_dir
	var session = get_node("/root/Session")
	session.state_changed.connect(_on_state)
	session.event.connect(_on_event)
	session.player_left.connect(func(_s, _w): _grab("14-disconnect", 0.35))
	get_node("/root/Room").game_started.connect(func(_s): _grab("04-deal", 0.7))
	get_node("/root/Room").seats_changed.connect(func(seats): if seats.size() >= 4: _grab("03-lobby", 0.5))


func on_screen(name: String) -> void:
	match name:
		"title": _grab("01-title", 0.4)
		"join": _grab("02-join", 0.05)
		"result":
			_grab("13-result", 0.9)
			get_tree().create_timer(3.0).timeout.connect(get_tree().quit)  ## 판이 끝났으니 창을 닫는다


func _table():
	var cur = main._current
	return cur.table if cur != null and "table" in cur else null


func _on_state(s: Dictionary) -> void:
	var p := _prev
	_prev = s
	if s.get("phase", "") == "done":
		return
	var me: int = s.seat
	var mine: bool = s.turn == me
	var top_changed: bool = not p.is_empty() and p.top.id != s.top.id
	match s.phase:
		"pick":
			if top_changed:
				var kind: String = s.top.kind
				if kind == "draw2" or kind == "wild4":
					_grab("09-attack", 0.45)
				elif kind == "skip":
					_grab("10a-skip", 0.35)
				elif kind == "rev":
					_grab("10b-reverse", 0.35)
				elif p.turn == me:
					_grab("06-play-fly", 0.12)
				else:
					_grab("07-opponent-play", 0.12)
			if mine:
				_grab("05-my-turn", 0.3)
			else:
				_grab("05b-wait", 0.5)
		"color":
			if mine:
				_grab("08-wild-picker", 0.3)
		"drawn":
			if mine:
				_grab("11-draw-choice", 0.3)
		"hanjang":
			if s.hanjang_seat == me:
				_grab("12a-my-hanjang", 0.3)
			else:
				_grab("12c-catch-button", 0.3)


func _on_event(ev: Dictionary) -> void:
	if ev.type == "hanjang_called":
		_grab("12b-called", 0.25)
	elif ev.type == "caught":
		_grab("12d-caught", 0.3)


func _grab(key: String, delay: float) -> void:
	if _done.has(key):
		return
	_done[key] = true
	await get_tree().create_timer(delay).timeout
	var t = _table()
	if key in ["05-my-turn", "05b-wait"] and (t == null or t.is_dealing()):
		_done.erase(key)
		return
	await RenderingServer.frame_post_draw
	var path := "%s/%s-%s.png" % [dir, key, get_node("/root/Room").my_name if get_node("/root/Room").my_name != "" else "창"]
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
