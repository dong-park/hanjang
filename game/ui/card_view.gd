class_name CardView
extends Control
## 카드 한 장을 그림 파일로 보여 준다. 값에 맞는 그림만 고르고, 상태만 바꾼다.
## color: "red" | "yellow" | "green" | "blue" | "wild"
## value: "0"~"9" | "skip" | "reverse" | "plus2" | "wild" | "wild4"

enum Lift { NONE, RAISED, PICKED }
enum CardSize { SMALL, NORMAL, LARGE }

const BASE_SIZE := Vector2(80, 112)  # 그림 한 장의 픽셀 크기 (배율 4)
const SCALES := {CardSize.SMALL: 0.5, CardSize.NORMAL: 1.0, CardSize.LARGE: 1.5}
const RAISE_PX := 16.0
const DIM := Color(0.45, 0.47, 0.58, 1)

var color := "red"
var value := "0"
var face_down := false
var lift: Lift = Lift.NONE
var dimmed := false
var card_size: CardSize = CardSize.NORMAL

var _tex := TextureRect.new()


static func texture_path(p_color: String, p_value: String) -> String:
	if p_value == "wild" or p_value == "wild4":
		return "res://assets/cards/%s.png" % p_value
	return "res://assets/cards/%s_%s.png" % [p_color, p_value]


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_tex)
	_refresh()


func show_card(p_color: String, p_value: String) -> void:
	color = p_color
	value = p_value
	face_down = false
	_refresh()


func show_back() -> void:
	face_down = true
	_refresh()


func set_lift(p_lift: Lift) -> void:
	lift = p_lift
	_refresh()


func set_dimmed(p_dimmed: bool) -> void:
	dimmed = p_dimmed
	_refresh()


func set_card_size(p_size: CardSize) -> void:
	card_size = p_size
	_refresh()


func card_pixel_size() -> Vector2:
	return BASE_SIZE * SCALES[card_size]


func current_texture_path() -> String:
	return "res://assets/cards/back.png" if face_down else texture_path(color, value)


func _refresh() -> void:
	var s: Vector2 = card_pixel_size()
	custom_minimum_size = s
	size = s
	_tex.texture = load(current_texture_path())
	_tex.size = s
	var up := 0.0
	if lift == Lift.RAISED:
		up = RAISE_PX * SCALES[card_size]
	elif lift == Lift.PICKED:
		up = RAISE_PX * 1.5 * SCALES[card_size]
	_tex.position = Vector2(0, -up)
	_tex.modulate = DIM if dimmed else Color.WHITE
	queue_redraw()


func _draw() -> void:
	if lift != Lift.PICKED:
		return
	var s: Vector2 = card_pixel_size()
	var up: float = RAISE_PX * 1.5 * SCALES[card_size]
	var t: float = 4.0 * SCALES[card_size] * 2.0
	draw_rect(Rect2(Vector2(-t, -up - t), s + Vector2(t * 2, t * 2)), Color(0.35, 0.88, 1, 1), false, t)

