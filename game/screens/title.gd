extends Control
## 장면 01 첫 화면. 닉네임(1~8자)과 아바타 4종을 고르고 방을 만들거나 참가 화면으로 간다.

var _name_edit: LineEdit
var _faces: Array[AvatarView] = []
var _face := 0
var _create_btn: Button
var _join_btn: Button
var _hint: Label
var _notice: Label
var _decor: Array[Control] = []     # 휴대폰 배치에서 숨기는 장식(로고, 부제, 카드)
var _name_label: Label
var _avatar_label: Label


func _ready() -> void:
	_face = Room.my_face
	var logo := Label.new()
	logo.text = "한장!"
	logo.theme_type_variation = &"BoldLabel"
	logo.add_theme_font_size_override("font_size", 88)
	_place(logo, Vector2(0, 60), Vector2(1152, 110))
	_decor.append(logo)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := Label.new()
	sub.text = "4인 온라인 카드게임"
	sub.add_theme_color_override("font_color", Color("8f9bd6"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(sub, Vector2(0, 176), Vector2(1152, 30))
	_decor.append(sub)
	var left := CardView.new()
	_place(left, Vector2(330, 90))
	left.show_card("red", "1")
	left.rotation_degrees = -12
	_decor.append(left)
	var right := CardView.new()
	_place(right, Vector2(740, 90))
	right.show_card("blue", "7")
	right.rotation_degrees = 12
	_decor.append(right)

	_name_label = _label("닉네임", Vector2(396, 258))
	_name_edit = LineEdit.new()
	_name_edit.max_length = Room.MAX_NAME
	_name_edit.text = Room.my_name
	_name_edit.placeholder_text = "1~8자"
	_place(_name_edit, Vector2(396, 284), Vector2(360, 54))
	_name_edit.text_changed.connect(func(_t): _refresh())
	_avatar_label = _label("아바타", Vector2(396, 348))
	for i in 4:
		var a := AvatarView.new()
		_place(a, Vector2(396 + i * 96, 376))
		a.mouse_filter = Control.MOUSE_FILTER_STOP
		a.gui_input.connect(_on_face_input.bind(i))
		a.size = AvatarView.FRAME_SIZE
		_faces.append(a)
	_create_btn = Button.new()
	_create_btn.text = "방 만들기"
	_place(_create_btn, Vector2(396, 490), Vector2(172, 62))
	_create_btn.pressed.connect(_on_create)
	_join_btn = Button.new()
	_join_btn.text = "참가하기"
	_place(_join_btn, Vector2(584, 490), Vector2(172, 62))
	_join_btn.pressed.connect(_on_join)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", Color("ffb74d"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_hint, Vector2(0, 562), Vector2(1152, 30))
	_notice = Label.new()
	_notice.add_theme_color_override("font_color", Color("ff8a80"))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_notice, Vector2(0, 14), Vector2(1152, 30))
	_refresh()
	if _uses_touch_keyboard():
		_phone_layout()   # 휴대폰은 첫 화면에서 키보드를 띄우지 않는다
	else:
		_name_edit.grab_focus()


func set_notice(text: String) -> void:
	## main이 호출한다 (방장이 나갔어요 등). _ready 뒤에 불린다.
	_notice.text = text


func _place(c: Control, pos: Vector2, sz := Vector2.ZERO) -> void:
	c.position = pos
	if sz != Vector2.ZERO:
		c.size = sz
	add_child(c)


## 휴대폰 웹에서만 화면 키보드가 판의 아래쪽 절반을 가린다.
func _uses_touch_keyboard() -> bool:
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


## 화면 키보드가 아래쪽 절반을 가리므로 입력칸과 버튼을 위쪽에 모은다. 칸을 누를 때 배치가 바뀌면
## 버튼이 손가락 밑에서 움직이므로, 처음부터 이 배치로 둔다. 아바타는 키보드를 닫으면 보인다.
func _phone_layout() -> void:
	for c in _decor:
		c.visible = false
	_name_label.position = Vector2(396, 18)
	_name_edit.position = Vector2(396, 44)
	_create_btn.position = Vector2(396, 116)
	_join_btn.position = Vector2(584, 116)
	_hint.position = Vector2(0, 186)
	_notice.position = Vector2(0, 190)  ## 이름칸 위 라벨과 겹치지 않게 입력칸 아래에 둔다
	_avatar_label.position = Vector2(396, 270)
	for i in _faces.size():
		_faces[i].position = Vector2(396 + i * 96, 298)


func _label(t: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color("8f9bd6"))
	_place(l, pos)
	return l


func _on_face_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_face = i
		_refresh()


func _refresh() -> void:
	var ok := Room.valid_name(_name_edit.text)
	_create_btn.disabled = not ok
	_join_btn.disabled = not ok
	_hint.text = "" if ok else "닉네임을 1~8자로 적어 주세요"
	for i in _faces.size():
		_faces[i].setup(i, "", AvatarView.State.TURN if i == _face else AvatarView.State.NORMAL)


func _save_profile() -> void:
	Room.my_name = _name_edit.text.strip_edges()
	Room.my_face = _face


func _on_create() -> void:
	if not Room.valid_name(_name_edit.text):
		return
	if Room.relay_base != "":
		_save_profile()
		get_parent().show_rooms(false)
		return
	if not Room.host_room(_name_edit.text, _face):
		_notice.text = "방을 열지 못했어요. 이미 열린 방이 있나요?"


func _on_join() -> void:
	if not Room.valid_name(_name_edit.text):
		return
	_save_profile()
	if Room.relay_base != "":
		get_parent().show_rooms(true)
	else:
		get_parent().show_join()
