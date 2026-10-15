extends Control
## 내 패. 부채꼴로 펼치고, 낼 수 있는 카드만 솟게 하고, 누르거나 위로 끌면 내기를 요청한다.
## 어두운 카드는 어떤 입력에도 반응하지 않는다.

const CardViewScript := preload("res://ui/card_view.gd")
const CardMap := preload("res://ui/card_map.gd")

signal card_chosen(card_id: int, from_pos: Vector2)

const DRAG_UP_PX := 36.0
const CARD_SIZE := Vector2(80, 112)

var interactive := false
var views := {}          # 카드 id -> CardView
var _playable := {}      # 카드 id -> true
var _press := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hand(cards: Array, playable_ids: Array, my_turn: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	views = {}
	_playable = {}
	_press = {}
	interactive = my_turn
	for id in playable_ids:
		_playable[id] = true
	var n := cards.size()
	var spacing := clampf(520.0 / maxf(n - 1, 1), 24.0, 76.0)
	for i in n:
		var card: Dictionary = cards[i]
		var cv = CardViewScript.new()
		add_child(cv)
		cv.show_card(CardMap.view_color(card), CardMap.view_value(card))
		if my_turn:
			if _playable.has(card.id):
				cv.set_lift(CardViewScript.Lift.RAISED)
			else:
				cv.set_dimmed(true)
		var t := float(i) - (n - 1) / 2.0
		cv.pivot_offset = CARD_SIZE / 2.0
		cv.position = Vector2(size.x / 2.0 + t * spacing - CARD_SIZE.x / 2.0, 44.0 + t * t * 1.4)
		cv.rotation = clampf(t * 0.045, -0.3, 0.3)
		cv.gui_input.connect(_on_card_input.bind(card.id))
		views[card.id] = cv


func _on_card_input(ev: InputEvent, card_id: int) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press = {"id": card_id, "y": ev.global_position.y, "fired": false}
		else:
			var fire: bool = _press.get("id", -1) == card_id and not _press.get("fired", true)
			_press = {}
			if fire:
				choose(card_id)
	elif ev is InputEventMouseMotion and _press.get("id", -1) == card_id and not _press.get("fired", true):
		if float(_press.y) - ev.global_position.y > DRAG_UP_PX:
			_press.fired = true
			choose(card_id)


## 카드 하나를 내려고 한다. 어두운 카드는 아무 일도 없다.
func choose(card_id: int) -> bool:
	if not interactive or not _playable.has(card_id) or not views.has(card_id):
		print("HAND ignored card id=", card_id)
		return false
	print("HAND play card id=", card_id)
	card_chosen.emit(card_id, views[card_id].get_global_rect().get_center())
	return true
