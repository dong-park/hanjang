extends Control
## 장면 02b 방 고르기(웹, 관리 서비스 경유). 코드로 입장 · 방 만들기(공개/비공개) · 공개 방 목록.
## 관리 서비스(relay/manager.py)가 없으면(예: LAN용 serve_web.py) 옛 참가 화면으로 돌아간다.
## 시험: --relay=http://127.0.0.1:8070 으로 웹이 아니어도 같은 화면을 쓴다.

const REFRESH_SEC := 3.0
const ROW_H := 56

var _code_edit: LineEdit
var _name_edit: LineEdit
var _public: CheckButton
var _create_btn: Button
var _enter_btn: Button
var _list_box: VBoxContainer
var _status: Label
var _made: Control            ## 방 만들기 뒤 코드·링크 카드
var _made_code := ""
var _made_secret := ""
var _made_name := ""
var _busy := false            ## 만들기·입장 요청 중
var _list_busy := false
var _listed := false          ## 목록을 한 번이라도 받았는가
var _auto_link := false


func setup(auto_link: bool) -> void:
	_auto_link = auto_link


func _ready() -> void:
	var back := Button.new()
	back.text = "뒤로"
	back.position = Vector2(24, 16)
	back.size = Vector2(110, 52)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func(): get_parent().show_title())
	add_child(back)
	var title := Label.new()
	title.text = "방 고르기"
	title.theme_type_variation = &"BoldLabel"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(1152, 46)
	add_child(title)

	_panel(Vector2(24, 84), Vector2(536, 112))
	_label("코드로 입장", Vector2(44, 94))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "4자리 코드"
	_code_edit.max_length = 4
	_code_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code_edit.add_theme_font_size_override("font_size", 24)
	_code_edit.position = Vector2(44, 126)
	_code_edit.size = Vector2(300, 56)
	_code_edit.text_changed.connect(_on_code_changed)
	_code_edit.text_submitted.connect(func(_t): _on_enter_code())
	add_child(_code_edit)
	_enter_btn = _button("입장", Vector2(358, 126), Vector2(184, 56), _on_enter_code)

	_panel(Vector2(24, 210), Vector2(536, 168))
	_label("방 만들기", Vector2(44, 220))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "방 이름 (12자까지)"
	_name_edit.max_length = 12
	_name_edit.text = "%s의 방" % Room.my_name
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.position = Vector2(44, 252)
	_name_edit.size = Vector2(300, 56)
	_name_edit.text_submitted.connect(func(_t): _on_create())
	add_child(_name_edit)
	_create_btn = _button("만들기", Vector2(358, 252), Vector2(184, 56), _on_create)
	_public = CheckButton.new()
	_public.text = "공개 방 (목록에 보여요)"
	_public.button_pressed = true
	_public.add_theme_font_size_override("font_size", 19)
	_public.position = Vector2(44, 318)
	_public.size = Vector2(500, 48)
	add_child(_public)

	_panel(Vector2(584, 84), Vector2(544, 440))
	_label("공개 방", Vector2(604, 94))
	var refresh := _button("새로고침", Vector2(968, 92), Vector2(140, 44), func(): _refresh_list())
	refresh.add_theme_font_size_override("font_size", 18)
	_list_box = VBoxContainer.new()
	_list_box.position = Vector2(604, 160)
	_list_box.size = Vector2(504, 360)
	_list_box.add_theme_constant_override("separation", 6)
	add_child(_list_box)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 20)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(0, 560)
	_status.size = Vector2(1152, 34)
	_status.z_index = 10  ## 코드 카드(어두운 막) 위에도 실패 문구가 보이게
	add_child(_status)

	Room.join_failed.connect(_on_join_failed)
	var timer := Timer.new()
	timer.wait_time = REFRESH_SEC
	timer.autostart = true
	timer.timeout.connect(func(): if not _busy and _made == null: _refresh_list())
	add_child(timer)
	_refresh_list()


func _panel(pos: Vector2, sz: Vector2) -> void:
	var p := PanelContainer.new()
	p.position = pos
	p.size = sz
	add_child(p)


func _label(t: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color("8f9bd6"))
	l.position = pos
	add_child(l)
	return l


func _button(t: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _say(t: String, bad := true) -> void:
	_status.add_theme_color_override("font_color", Color("ff8a80") if bad else Color("e8ecff"))
	_status.text = t


func _on_code_changed(t: String) -> void:
	var digits := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits != t:
		_code_edit.text = digits
		_code_edit.caret_column = digits.length()


## 관리 서비스 호출. cb(성공 여부, HTTP 코드, 해석한 본문)
func _call(method: int, path: String, body, cb: Callable) -> void:
	var h := HTTPRequest.new()
	h.accept_gzip = false  ## 웹은 브라우저(터널의 압축 포함)가 이미 풀어서 준다. 한 번 더 풀려 하면 실패한다
	add_child(h)
	h.request_completed.connect(func(result: int, code: int, _hd: PackedStringArray, data: PackedByteArray):
		h.queue_free()
		var parsed = JSON.parse_string(data.get_string_from_utf8()) if data.size() > 0 else null
		cb.call(result == HTTPRequest.RESULT_SUCCESS, code, parsed))
	var payload := "" if body == null else JSON.stringify(body)
	if h.request(Room.relay_base + path, ["Content-Type: application/json"], method, payload) != OK:
		h.queue_free()
		cb.call(false, 0, null)


func _refresh_list() -> void:
	if _list_busy:
		return
	_list_busy = true
	_call(HTTPClient.METHOD_GET, "/api/rooms", null, func(ok: bool, code: int, data):
		_list_busy = false
		if ok and code == 200 and data is Array:
			_listed = true
			_show_list(data)
			if _status.text == "서버에 닿지 못했어요":
				_say("")
			if _auto_link:
				_auto_link = false
				var c := Room.link_room()
				if c != "":
					_code_edit.text = c
					_enter(c)
			return
		if not _listed:
			get_parent().show_join()  ## 관리 서비스가 없는 주소 (LAN용 웹)
		else:
			_say("서버에 닿지 못했어요"))


func _show_list(rooms: Array) -> void:
	for c in _list_box.get_children():
		c.queue_free()
	if rooms.is_empty():
		var none := Label.new()
		none.text = "열린 공개 방이 아직 없어요"
		none.add_theme_font_size_override("font_size", 20)
		none.add_theme_color_override("font_color", Color("5f6a9e"))
		_list_box.add_child(none)
		return
	for r in rooms.slice(0, 6):
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(504, ROW_H)
		row.add_theme_constant_override("separation", 10)
		var nm := Label.new()
		nm.text = str(r.name)
		nm.add_theme_font_size_override("font_size", 22)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nm)
		var info := Label.new()
		var playing: bool = r.state == "playing"
		info.text = "%d/%d · %s" % [int(r.players), int(r.capacity), "판 중" if playing else "대기 중"]
		info.add_theme_font_size_override("font_size", 18)
		info.add_theme_color_override("font_color", Color("ffb74d") if playing else Color("5fe3ff"))
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(info)
		var go := Button.new()
		go.text = "입장"
		go.disabled = not bool(r.joinable)
		go.custom_minimum_size = Vector2(96, ROW_H)
		go.add_theme_font_size_override("font_size", 20)
		var code := str(r.code)
		go.pressed.connect(func(): _enter(code))
		row.add_child(go)
		_list_box.add_child(row)


func _on_enter_code() -> void:
	if _code_edit.text.length() != 4:
		_say("4자리 코드를 적어 주세요")
		return
	_enter(_code_edit.text)


## 코드로 방 정보를 받아(비밀값 포함) 웹소켓으로 들어간다.
func _enter(code: String) -> void:
	if _busy:
		return
	_busy = true
	_say("들어가는 중 · · ·", false)
	_call(HTTPClient.METHOD_GET, "/api/rooms/" + code, null, func(ok: bool, hcode: int, data):
		if not ok:
			_busy = false
			_say("서버에 닿지 못했어요")
			return
		if hcode != 200 or not data is Dictionary:
			_busy = false
			_say(str(data.error) if data is Dictionary and data.has("error") else "방을 못 찾았어요")
			_refresh_list()
			return
		if data.state == "playing":
			_busy = false
			_say("이미 시작한 방이에요")
			return
		if int(data.players) >= int(data.capacity):
			_busy = false
			_say("지금은 방이 가득 찼어요")
			return
		Room.my_secret = str(data.secret)
		Room.room_name_override = str(data.name)
		if not Room.join_room(Room.my_name, Room.my_face, Room.relay_ws(code)):
			_busy = false)


func _on_join_failed(reason: String) -> void:
	_busy = false
	_say(reason)


func _on_create() -> void:
	if _busy:
		return
	var nm := _name_edit.text.strip_edges()
	if nm == "":
		_say("방 이름을 적어 주세요")
		return
	_busy = true
	_say("방을 여는 중 · · ·", false)
	_call(HTTPClient.METHOD_POST, "/api/rooms", {"name": nm, "public": _public.button_pressed}, func(ok: bool, hcode: int, data):
		_busy = false
		if not ok:
			_say("서버에 닿지 못했어요")
		elif hcode == 201 and data is Dictionary:
			_say("")
			_show_made(data)
		else:
			_say(str(data.error) if data is Dictionary and data.has("error") else "방을 열지 못했어요"))


## 방 만들기 뒤: 4자리 코드와 공유 링크를 보이고 들어가기를 누르게 한다.
func _show_made(info: Dictionary) -> void:
	_made_code = str(info.code)
	_made_secret = str(info.secret)
	_made_name = str(info.name)
	var link := "%s/?room=%s" % [Room.relay_base, _made_code]
	_made = Control.new()
	_made.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.12, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_made.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(236, 86)
	panel.size = Vector2(680, 440)
	_made.add_child(panel)
	var head := Label.new()
	head.text = "%s 방이 열렸어요" % ("공개" if bool(info.public) else "비공개")
	head.theme_type_variation = &"BoldLabel"
	head.add_theme_font_size_override("font_size", 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(236, 108)
	head.size = Vector2(680, 46)
	_made.add_child(head)
	var code := Label.new()
	code.text = _made_code
	code.theme_type_variation = &"BoldLabel"
	code.add_theme_font_size_override("font_size", 96)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.position = Vector2(236, 166)
	code.size = Vector2(680, 120)
	_made.add_child(code)
	var hint := Label.new()
	hint.text = "친구에게 코드나 아래 링크를 알려 주세요"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("8f9bd6"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(236, 292)
	hint.size = Vector2(680, 28)
	_made.add_child(hint)
	var link_edit := LineEdit.new()
	link_edit.text = link
	link_edit.editable = false
	link_edit.add_theme_font_size_override("font_size", 18)
	link_edit.position = Vector2(276, 328)
	link_edit.size = Vector2(600, 48)
	_made.add_child(link_edit)
	var copy := Button.new()
	copy.text = "링크 복사"
	copy.position = Vector2(276, 396)
	copy.size = Vector2(190, 62)
	copy.add_theme_font_size_override("font_size", 22)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(link)
		copy.text = "복사했어요")
	_made.add_child(copy)
	var go := Button.new()
	go.text = "들어가기"
	go.position = Vector2(486, 396)
	go.size = Vector2(190, 62)
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(_enter_made)
	_made.add_child(go)
	var cancel := Button.new()
	cancel.text = "닫기"
	cancel.position = Vector2(696, 396)
	cancel.size = Vector2(180, 62)
	cancel.add_theme_font_size_override("font_size", 22)
	cancel.pressed.connect(func(): _made.queue_free(); _made = null; _refresh_list())
	_made.add_child(cancel)
	add_child(_made)


func _enter_made() -> void:
	if _busy:
		return
	_busy = true
	Room.my_secret = _made_secret
	Room.room_name_override = _made_name
	if not Room.join_room(Room.my_name, Room.my_face, Room.relay_ws(_made_code)):
		_busy = false
