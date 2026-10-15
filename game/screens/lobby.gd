extends Control
## 장면 03 대기실. 자리 4개, 방장 왕관, 방 주소, 방장만 누르는 시작 버튼.
## 들어온 사람은 "준비 완료"로 보인다 (spec 확인 안 된 것: 준비 버튼은 없다).

const SLOT := Vector2(204, 250)

var _title: Label
var _addr: Label
var _slots: Array[Control] = []
var _start: Button
var _info: Label
var _leave: Button


func _ready() -> void:
	_title = Label.new()
	_title.theme_type_variation = &"BoldLabel"
	_title.add_theme_font_size_override("font_size", 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 38)
	_title.size = Vector2(1152, 50)
	add_child(_title)
	var addr_panel := PanelContainer.new()
	addr_panel.position = Vector2(446, 94)
	addr_panel.size = Vector2(260, 48)
	add_child(addr_panel)
	_addr = Label.new()
	_addr.theme_type_variation = &"BoldLabel"
	_addr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_addr.position = Vector2(446, 102)
	_addr.size = Vector2(260, 34)
	add_child(_addr)
	for i in Room.MAX_PLAYERS:
		var p := Panel.new()
		p.position = Vector2(120 + i * 236, 170)
		p.size = SLOT
		add_child(p)
		_slots.append(p)
	_start = Button.new()
	_start.text = "시작!"
	_start.position = Vector2(476, 470)
	_start.size = Vector2(200, 64)
	_start.pressed.connect(Room.start_game)
	add_child(_start)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	_info.add_theme_color_override("font_color", Color("a9b4e8"))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.position = Vector2(0, 548)
	_info.size = Vector2(1152, 28)
	add_child(_info)
	_leave = Button.new()
	_leave.text = "나가기"
	_leave.position = Vector2(24, 24)
	_leave.size = Vector2(120, 48)
	_leave.add_theme_font_size_override("font_size", 18)
	_leave.pressed.connect(func(): Room.leave(); get_parent().show_title())
	add_child(_leave)
	Room.seats_changed.connect(_refresh)
	_refresh(Room.seats)


func _refresh(seats: Array) -> void:
	_title.text = Room.room_name()
	_addr.text = "방 주소 %s" % Room.addr
	for i in _slots.size():
		var slot: Control = _slots[i]
		for c in slot.get_children():
			c.queue_free()
		var cx := SLOT.x / 2.0
		if i < seats.size():
			var s: Dictionary = seats[i]
			var a := AvatarView.new()
			a.position = Vector2(cx - AvatarView.FRAME_SIZE.x / 2.0, 54)
			slot.add_child(a)
			a.setup(s.face, s.name, AvatarView.State.NORMAL, i == 0)
			var tag := Label.new()
			tag.text = "방장" if i == 0 else "준비 완료"
			tag.add_theme_font_size_override("font_size", 18)
			tag.add_theme_color_override("font_color", Color("ffc13b") if i == 0 else Color("5fe3ff"))
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.position = Vector2(0, 176)
			tag.size = Vector2(SLOT.x, 28)
			slot.add_child(tag)
		else:
			var q := Label.new()
			q.text = "?"
			q.theme_type_variation = &"BoldLabel"
			q.add_theme_font_size_override("font_size", 40)
			q.add_theme_color_override("font_color", Color("5f6a9e"))
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.position = Vector2(cx - 44, 54)
			q.size = Vector2(88, 88)
			slot.add_child(q)
			var w := Label.new()
			w.text = "기다리는 중…"
			w.add_theme_font_size_override("font_size", 18)
			w.add_theme_color_override("font_color", Color("5f6a9e"))
			w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			w.position = Vector2(0, 176)
			w.size = Vector2(SLOT.x, 28)
			slot.add_child(w)
	var host := Room.is_host()
	_start.visible = true
	_start.disabled = not (host and seats.size() >= Room.MIN_PLAYERS)
	if not host:
		_info.text = "방장이 시작해요 · %d/%d명" % [seats.size(), Room.MAX_PLAYERS]
	elif seats.size() < Room.MIN_PLAYERS:
		_info.text = "2명 이상 모이면 시작할 수 있어요 · %d/%d명" % [seats.size(), Room.MAX_PLAYERS]
	else:
		_info.text = "방장만 누를 수 있어요 · %d/%d명" % [seats.size(), Room.MAX_PLAYERS]

