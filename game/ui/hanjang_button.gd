extends Control
## 한장! 창. 낸 사람 화면에는 [한장!] 버튼, 다른 사람 화면에는 "1장 남음!"과 [잡았다!] 버튼, 둘 다 창 시간 바가 줄어든다.
## 누르면 pressed_action("call" | "catch")만 보낸다. 창을 닫는 것은 방장이다.

signal pressed_action(kind: String)

const RED_BG := Color("b3252b")
const RED_EDGE := Color("ff7070")

var mode := ""
var btn: Button
var bar: ProgressBar
var label: Label
var panel: Panel
var _pulse: Tween
var _drain: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = Panel.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("1c2340")
	psb.border_color = Color("3a4a8a")
	psb.set_border_width_all(3)
	psb.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", psb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(872, 24)
	panel.size = Vector2(256, 176)
	add_child(panel)
	label = Label.new()
	label.position = Vector2(888, 40)
	label.size = Vector2(224, 30)
	label.add_theme_font_size_override("font_size", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	btn = Button.new()
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = RED_BG if st != "disabled" else Color("6a2a30")
		sb.border_color = RED_EDGE if st != "disabled" else Color("8a5a60")
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(3)
		if st == "hover":
			sb.bg_color = Color("c82c32")
		btn.add_theme_stylebox_override(st, sb)
	btn.pressed.connect(func(): pressed_action.emit(mode))
	add_child(btn)
	bar = ProgressBar.new()
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("2a2030")
	bg.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff6b6b")
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	hide_all()


func hide_all() -> void:
	mode = ""
	for n in [panel, label, btn, bar]:
		n.visible = false
	if _pulse:
		_pulse.kill()
	if _drain:
		_drain.kill()


## m: "call"(내가 낸 사람) | "catch"(남이 낸 사람). restart 가 참일 때만 시간 바를 다시 시작한다.
func show_mode(m: String, who: String, left: float, total: float, restart: bool) -> void:
	mode = m
	var is_call := m == "call"
	panel.visible = not is_call
	label.visible = not is_call
	label.text = "%s: 1장 남음!" % who
	btn.visible = true
	btn.disabled = false
	bar.visible = true
	btn.text = "한장!" if is_call else "잡았다!"
	btn.add_theme_font_size_override("font_size", 40 if is_call else 30)
	if is_call:
		btn.position = Vector2(470, 400)
		btn.size = Vector2(212, 72)
		bar.position = Vector2(470, 484)
		bar.size = Vector2(212, 12)
	else:
		btn.position = Vector2(904, 82)
		btn.size = Vector2(192, 60)
		bar.position = Vector2(904, 154)
		bar.size = Vector2(192, 12)
	if not restart:
		return
	bar.max_value = total
	bar.value = left
	if _drain:
		_drain.kill()
	_drain = create_tween()
	_drain.tween_property(bar, "value", 0.0, maxf(left, 0.01))
	if _pulse:
		_pulse.kill()
	btn.self_modulate = Color.WHITE
	_pulse = create_tween().set_loops()
	_pulse.tween_property(btn, "self_modulate", Color(1.35, 1.2, 1.2), 0.35)
	_pulse.tween_property(btn, "self_modulate", Color.WHITE, 0.35)
