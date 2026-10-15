extends Control
## 와일드 색 고르기 팝업(장면 08).

signal color_chosen(color: int)

const COLOR_RGB := [Color("e8343a"), Color("f2b51c"), Color("2fa84f"), Color("2f6fe0")]
const COLOR_NAME := ["빨강", "노랑", "초록", "파랑"]

var buttons: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.position = Vector2(356, 170)
	panel.size = Vector2(440, 290)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var title := Label.new()
	title.text = "무슨 색으로 할까요?"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(356, 198)
	title.size = Vector2(440, 40)
	add_child(title)
	for i in 4:
		var x := 394.0 + i * 96.0
		var b := Button.new()
		b.position = Vector2(x, 256)
		b.size = Vector2(76, 108)
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = COLOR_RGB[i]
			sb.set_border_width_all(4)
			sb.border_color = Color("5be0ff") if st != "normal" else Color.WHITE
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func(): color_chosen.emit(i))
		add_child(b)
		buttons.append(b)
		var l := Label.new()
		l.text = COLOR_NAME[i]
		l.add_theme_font_size_override("font_size", 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(x - 12, 376)
		l.size = Vector2(100, 28)
		add_child(l)
