extends Control
## 장면 02 참가. 방장 주소를 적거나 최근 방을 눌러 들어간다. 실패하면 이 화면에 남는다.

var _addr_edit: LineEdit
var _status: Label
var _go_btn: Button
var _recent_box: VBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(336, 96)
	_panel.size = Vector2(480, 420)
	add_child(_panel)
	var title := Label.new()
	title.text = "방 참가하기"
	title.theme_type_variation = &"BoldLabel"
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(376, 130)
	add_child(title)
	_label("방장 주소", Vector2(376, 190))
	_addr_edit = LineEdit.new()
	_addr_edit.placeholder_text = "예: 192.168.0.12"
	var recent := Room.recent_rooms()
	if recent.size() > 0:
		_addr_edit.text = recent[0].addr
	_addr_edit.position = Vector2(376, 216)
	_addr_edit.size = Vector2(400, 52)
	_addr_edit.text_submitted.connect(func(_t): _connect())
	add_child(_addr_edit)
	_label("최근 방", Vector2(376, 282))
	_recent_box = VBoxContainer.new()
	_recent_box.position = Vector2(376, 308)
	_recent_box.size = Vector2(400, 60)
	add_child(_recent_box)
	if recent.is_empty():
		var none := Label.new()
		none.text = "아직 없어요"
		none.add_theme_color_override("font_color", Color("5f6a9e"))
		_recent_box.add_child(none)
	for r in recent.slice(0, 2):
		var b := Button.new()
		b.text = "%s · %s" % [r.name, r.addr]
		b.custom_minimum_size = Vector2(400, 44)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func(): _addr_edit.text = r.addr; _connect())
		_recent_box.add_child(b)
	_go_btn = Button.new()
	_go_btn.text = "접속"
	_go_btn.position = Vector2(376, 424)
	_go_btn.size = Vector2(190, 58)
	_go_btn.pressed.connect(_connect)
	add_child(_go_btn)
	var back := Button.new()
	back.text = "뒤로"
	back.position = Vector2(586, 424)
	back.size = Vector2(190, 58)
	back.pressed.connect(func(): Room.leave(); get_parent().show_title())
	add_child(back)
	_status = Label.new()
	_status.position = Vector2(0, 540)
	_status.size = Vector2(1152, 32)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)
	Room.join_failed.connect(_on_failed)
	_addr_edit.grab_focus()
	if OS.get_cmdline_user_args().has("--shot=join"):
		_addr_edit.text = "192.168.0.12"
		_status.text = "접속 중 · · ·"


func _label(t: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color("8f9bd6"))
	l.position = pos
	add_child(l)


func _connect() -> void:
	if _addr_edit.text.strip_edges() == "":
		_status.add_theme_color_override("font_color", Color("ffb74d"))
		_status.text = "방장 주소를 적어 주세요"
		return
	_status.add_theme_color_override("font_color", Color("e8ecff"))
	_status.text = "접속 중 · · ·"
	Room.join_room(Room.my_name, Room.my_face, _addr_edit.text)


func _on_failed(reason: String) -> void:
	_status.add_theme_color_override("font_color", Color("ff8a80"))
	_status.text = reason

