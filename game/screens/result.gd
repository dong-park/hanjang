extends Control
## 장면 13 결과. 등수와 남은 장수. 방장이 다시 하기·대기실로를 고르고, 접속자는 방장을 기다린다.

const PLACE := ["", "1등", "2등", "3등", "4등"]

## 자동 로드(Session, Room)는 경로로 잡는다. 화면 시험이 가짜 노드를 같은 이름으로 세울 수 있다.
var _session
var _room


func _ready() -> void:
	_session = get_node("/root/Session")
	_room = get_node("/root/Room")
	var snap: Dictionary = _session.last_snap
	var title := Label.new()
	title.text = "결과"
	title.theme_type_variation = &"BoldLabel"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(1152, 60)
	add_child(title)
	var rows: Array = []
	for i in _session.seats.size():
		var rank: int = snap.ranks[i] if i < snap.get("ranks", []).size() else 0
		rows.append({"seat": i, "rank": rank})
	rows.sort_custom(func(a, b):
		var ka: int = a.rank if a.rank > 0 else 99
		var kb: int = b.rank if b.rank > 0 else 99
		return ka < kb if ka != kb else a.seat < b.seat)
	for k in rows.size():
		_row(rows[k], k, snap)
	if _room.is_host():
		_button("다시 하기", Vector2(300, 520), func(): _room.replay())
		_button("대기실로", Vector2(650, 520), func(): _room.back_to_lobby())
	else:
		var wait := Label.new()
		wait.text = "방장을 기다려요"
		wait.add_theme_font_size_override("font_size", 24)
		wait.add_theme_color_override("font_color", Color("a9b4e8"))
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wait.position = Vector2(0, 536)
		wait.size = Vector2(1152, 40)
		add_child(wait)
	print("RESULT_SHOWN ", rows.map(func(r): return "%d:%d" % [r.seat, r.rank]))


func _row(r: Dictionary, k: int, snap: Dictionary) -> void:
	var seat: int = r.seat
	var s: Dictionary = _session.seats[seat]
	var gone: bool = r.rank == 0
	var p := Panel.new()
	p.position = Vector2(236, 120 + k * 94)
	p.size = Vector2(680, 84)
	if gone:
		p.modulate = Color(0.6, 0.6, 0.6)
	add_child(p)
	var place := Label.new()
	place.text = "나감" if gone else PLACE[clampi(r.rank, 0, 4)]
	place.theme_type_variation = &"BoldLabel"
	place.add_theme_font_size_override("font_size", 30)
	place.add_theme_color_override("font_color", Color("ffc13b") if r.rank == 1 else Color.WHITE)
	place.position = Vector2(24, 20)
	place.size = Vector2(110, 44)
	p.add_child(place)
	var nm := Label.new()
	nm.text = s.name + (" (방장)" if seat == 0 else "")
	nm.add_theme_font_size_override("font_size", 26)
	nm.position = Vector2(160, 22)
	nm.size = Vector2(320, 40)
	p.add_child(nm)
	var left := Label.new()
	if gone:
		left.text = "연결이 끊겼어요"
	elif r.rank == 1:
		left.text = "다 털었어요!"
	else:
		left.text = "남은 카드 %d장" % snap.counts[seat]
	left.add_theme_font_size_override("font_size", 22)
	left.add_theme_color_override("font_color", Color("a9b4e8"))
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left.position = Vector2(400, 26)
	left.size = Vector2(260, 34)
	p.add_child(left)


func _button(text: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(200, 64)
	b.pressed.connect(func():
		b.disabled = true
		cb.call())
	add_child(b)
