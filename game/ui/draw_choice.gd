extends Control
## 뽑은 카드를 크게 보이고 바로 내기·가지기를 고른다(장면 11).

signal play_now
signal keep

const CardViewScript := preload("res://ui/card_view.gd")
const CardMap := preload("res://ui/card_map.gd")
const COLOR_NAME := ["빨강", "노랑", "초록", "파랑"]

var card_view
var hint: Label
var play_button: Button
var keep_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_view = CardViewScript.new()
	add_child(card_view)
	card_view.set_card_size(CardViewScript.CardSize.LARGE)
	card_view.position = Vector2(515, 182)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(425, 150)
	hint.size = Vector2(300, 30)
	add_child(hint)
	play_button = Button.new()
	play_button.text = "바로 내기"
	play_button.position = Vector2(424, 362)
	play_button.size = Vector2(144, 52)
	play_button.modulate = Color(1.25, 1.5, 1.6)
	play_button.pressed.connect(func(): play_now.emit())
	add_child(play_button)
	keep_button = Button.new()
	keep_button.text = "가지기"
	keep_button.position = Vector2(584, 362)
	keep_button.size = Vector2(144, 52)
	keep_button.pressed.connect(func(): keep.emit())
	add_child(keep_button)


func show_drawn(card: Dictionary) -> void:
	card_view.show_card(CardMap.view_color(card), CardMap.view_value(card))
	if card.color >= 0:
		hint.text = COLOR_NAME[card.color] + "이라 낼 수 있어요!"
	else:
		hint.text = "낼 수 있어요!"
