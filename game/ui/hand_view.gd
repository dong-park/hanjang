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
var selected := -1       # 손가락으로 올려 둔(한 번 누른) 카드 id. 한 번 더 누르면 낸다.


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## active: 내 차례의 고르는 중. 아니면 패 전체가 어둡고 눌러도 반응하지 않는다.
func set_hand(cards: Array, playable_ids: Array, active: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	views = {}
	_playable = {}
	_press = {}
	selected = -1
	interactive = active
	for id in playable_ids:
		_playable[id] = true
	var n := cards.size()
	var spacing := clampf(520.0 / maxf(n - 1, 1), 24.0, 76.0)
	for i in n:
		var card: Dictionary = cards[i]
		var cv = CardViewScript.new()
		add_child(cv)
		cv.show_card(CardMap.view_color(card), CardMap.view_value(card))
		if active and _playable.has(card.id):
			cv.set_lift(CardViewScript.Lift.RAISED)
		else:
			cv.set_dimmed(true)
		var t := float(i) - (n - 1) / 2.0
		cv.pivot_offset = CARD_SIZE / 2.0
		cv.position = Vector2(size.x / 2.0 + t * spacing - CARD_SIZE.x / 2.0, 44.0 + t * t * 1.4)
		cv.rotation = clampf(t * 0.045, -0.3, 0.3)
		cv.gui_input.connect(_on_card_input.bind(card.id))
		views[card.id] = cv


## 내 차례가 시작될 때: 어두운 패에서 밝아지고, 낼 수 있는 카드는 살짝 튄다.
func flash_in() -> void:
	for id in views:
		var cv = views[id]
		cv.modulate = Color(0.5, 0.5, 0.6)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(cv, "modulate", Color.WHITE, 0.4)
		if _playable.has(id):
			cv.scale = Vector2(1.1, 1.1)
			tw.tween_property(cv, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 손가락 터치는 엔진이 마우스로 바꿔 보낸다(device == DEVICE_ID_EMULATION). 마우스는 그대로 한 번 누르면 낸다.
static func is_touch(ev: InputEvent) -> bool:
	return ev.device == InputEvent.DEVICE_ID_EMULATION


func _on_card_input(ev: InputEvent, card_id: int) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_press = {"id": card_id, "y": ev.global_position.y, "fired": false, "touch": is_touch(ev)}
		else:
			var fire: bool = _press.get("id", -1) == card_id and not _press.get("fired", true)
			var touch: bool = _press.get("touch", false)
			_press = {}
			if fire:
				if touch:
					tap(card_id)
				else:
					choose(card_id)
	elif ev is InputEventMouseMotion and _press.get("id", -1) == card_id and not _press.get("fired", true):
		if float(_press.y) - ev.global_position.y > DRAG_UP_PX:
			_press.fired = true
			deselect()
			choose(card_id)


## 손가락 빈 곳 누르기는 올려 둔 카드를 내린다. 카드 위 누르기는 카드가 처리한다.
func _input(ev: InputEvent) -> void:
	if selected < 0 or not (ev is InputEventMouseButton) or not ev.pressed or not is_touch(ev):
		return
	for cv in views.values():
		if cv.get_global_rect().has_point(ev.global_position):
			return
	deselect()


## 손가락으로 카드를 한 번 누른다. 처음엔 올리기만 하고, 올라간 같은 카드를 또 누르면 낸다.
## 다른 카드를 누르면 올린 카드가 내려간다. 낼 수 없는 카드는 올라가지 않는다.
func tap(card_id: int) -> bool:
	if selected == card_id:
		deselect()
		return choose(card_id)
	deselect()
	if not interactive or not _playable.has(card_id) or not views.has(card_id):
		print("HAND ignored tap id=", card_id)
		return false
	selected = card_id
	views[card_id].set_lift(CardViewScript.Lift.PICKED)
	print("HAND picked card id=", card_id)
	return true


func deselect() -> void:
	if selected >= 0 and views.has(selected):
		views[selected].set_lift(CardViewScript.Lift.RAISED)
	selected = -1


## 카드 하나를 내려고 한다. 어두운 카드는 아무 일도 없다.
func choose(card_id: int) -> bool:
	if not interactive or not _playable.has(card_id) or not views.has(card_id):
		print("HAND ignored card id=", card_id)
		return false
	print("HAND play card id=", card_id)
	card_chosen.emit(card_id, views[card_id].get_global_rect().get_center())
	return true

