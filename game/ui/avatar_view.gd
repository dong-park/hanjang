class_name AvatarView
extends Control
## 네모 아바타 칸. 얼굴, 이름, 차례 빛남, 회색, 방장 왕관을 보여 준다.

enum State { NORMAL, TURN, GRAY }

const FRAME_SIZE := Vector2(88, 88)   # 22칸 x 배율 4
const FACE_COUNT := 4

var face := 0
var nickname := ""
var state: State = State.NORMAL
var is_host := false

var _frame := TextureRect.new()
var _face := TextureRect.new()
var _crown := TextureRect.new()
var _name := Label.new()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(FRAME_SIZE.x, FRAME_SIZE.y + 28)
	for t in [_frame, _face, _crown]:
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(t)
	_frame.size = FRAME_SIZE
	_face.position = Vector2(12, 12)
	_face.size = Vector2(64, 64)
	_crown.texture = load("res://assets/ui/crown.png")
	_crown.size = Vector2(36, 24)
	_crown.position = Vector2(26, -22)
	_name.position = Vector2(-20, FRAME_SIZE.y + 4)
	_name.size = Vector2(FRAME_SIZE.x + 40, 24)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 22)
	add_child(_name)
	_refresh()


func setup(p_face: int, p_name: String, p_state: State = State.NORMAL, p_host := false) -> void:
	face = posmod(p_face, FACE_COUNT)
	nickname = p_name
	state = p_state
	is_host = p_host
	_refresh()


func _refresh() -> void:
	var names := ["normal", "turn", "gray"]
	_frame.texture = load("res://assets/ui/avatar_frame_%s.png" % names[state])
	_face.texture = load("res://assets/avatars/face_%d.png" % face)
	_face.modulate = Color(0.45, 0.45, 0.5, 1) if state == State.GRAY else Color.WHITE
	_crown.visible = is_host
	_name.text = nickname

