extends Control
## 화면 전환 담당. 첫 화면 → (참가 →) 대기실 → 시작 신호. 방 연결은 Room(autoload)이 한다.
## 시험용 인자: --host --join=IP --name=닉 --face=N --port=N --try-start=초,초 --leave-after=초 --shot=title|join|lobby --result-pick=replay|lobby
##   --leave-at-game=N --leave-delay=초 (N번째 판이 시작되고 초 뒤에 나간다)
## 장면 캡처: --shots=폴더 (tests/scene_shots.gd)

const THEME := preload("res://ui/theme.tres")
const BG_TILE := preload("res://assets/ui/bg_tile.png")
const TitleScreen := preload("res://screens/title.tscn")
const JoinScreen := preload("res://screens/join.tscn")
const LobbyScreen := preload("res://screens/lobby.tscn")
const TableNetScreen := preload("res://screens/table_net.tscn")
const ResultScreen := preload("res://screens/result.tscn")

var _current: Control
var _notice := ""
var _opts := {}
var _games := 0
var _shots


func _ready() -> void:
	if "--local" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://screens/table_local.tscn")
		return
	theme = THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = BG_TILE
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	Room.joined.connect(func(): show_screen(LobbyScreen))
	Room.lobby_returned.connect(func(): show_screen(LobbyScreen))
	Room.left_to_title.connect(func(reason): _notice = reason; show_screen(TitleScreen))
	Room.game_started.connect(_on_game_started)
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if _opts.has("port"):
		Room.port = int(_opts.port)
	if _opts.has("shots"):
		_shots = load("res://tests/scene_shots.gd").new()
		add_child(_shots)
		_shots.setup(self, _opts.shots)
	show_screen(TitleScreen)
	_run_cmdline()


func show_screen(scene: PackedScene) -> void:
	if _current:
		_current.queue_free()
	_current = scene.instantiate()
	_current.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_current)
	if _current.has_method("set_notice"):
		_current.set_notice(_notice)
	_notice = ""
	print("SCREEN ", _current.scene_file_path.get_file().get_basename())
	if _shots:
		_shots.on_screen(_current.scene_file_path.get_file().get_basename())


func show_title() -> void:
	show_screen(TitleScreen)


func show_join() -> void:
	show_screen(JoinScreen)


func _on_game_started(_seats: Array) -> void:
	if Room.dedicated:
		return  ## 전용 방 프로세스는 화면 없이 판정만 한다
	show_screen(TableNetScreen)
	_current.finished.connect(_show_result)
	_games += 1
	if _opts.get("leave-at-game", "") == str(_games):
		get_tree().create_timer(float(_opts.get("leave-delay", 0.1))).timeout.connect(func():
			Room.leave()
			get_tree().create_timer(0.5).timeout.connect(get_tree().quit))


func _show_result() -> void:
	show_screen(ResultScreen)
	var pick: String = _opts.get("result-pick", "")
	if pick != "" and Room.can_control():  ## 시험용: 방장이 1초 뒤 replay 또는 lobby 를 고른다
		get_tree().create_timer(1.0).timeout.connect(func():
			if pick == "replay":
				Room.replay()
			else:
				Room.back_to_lobby())


func _run_cmdline() -> void:
	## 명령줄 실행용: -- --host 또는 -- --join=IP (닉네임은 --name, 아바타는 --face)
	var nick: String = _opts.get("name", "")
	var face := int(_opts.get("face", 0))
	if _opts.has("dedicated"):
		## 전용 방: --dedicated --port=N --code=방코드 --room-name=이름 --public=0|1 (자리 없이 판정만, 화면 전환 없음)
		Room.room_name_override = str(_opts.get("room-name", ""))
		if not Room.host_dedicated(str(_opts.get("code", "")), str(_opts.get("public", "0")) == "1"):
			print("HOST_FAILED port=", Room.port)
			get_tree().quit(1)
	elif _opts.has("host"):
		Room.host_room(nick, face)
	elif _opts.has("join"):
		show_screen(JoinScreen)
		Room.join_room(nick, face, _opts.join)
	if _opts.has("try-start"):
		for sec in str(_opts["try-start"]).split(","):
			get_tree().create_timer(float(sec)).timeout.connect(Room.start_game)
	if _opts.has("leave-after"):
		get_tree().create_timer(float(_opts["leave-after"])).timeout.connect(func():
			Room.leave()
			get_tree().create_timer(0.5).timeout.connect(get_tree().quit))
	if _opts.has("quit-after"):
		get_tree().create_timer(float(_opts["quit-after"])).timeout.connect(get_tree().quit)
	if _opts.get("shot", "") == "join":
		show_screen(JoinScreen)

