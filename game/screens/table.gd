extends Control
## 판 화면. 그리기는 apply_snapshot(dict) 하나로만, 행동은 action_requested 시그널 하나로만 나간다.
## 네트워크를 모른다. 로컬 드라이버(table_local.gd)와 n7의 세션이 같은 입구를 쓴다.
##
## apply_snapshot 입력: rules.gd 의 snapshot_for(seat) 형태.
## action_requested 로 나가는 것:
##   {"type": "play", "id": 카드 id, "color": -1}   와일드는 이어서 색 고르기 팝업 → choose_color
##   {"type": "choose_color", "color": 0~3}
##   {"type": "draw"}   {"type": "keep"}(뽑은 카드 가지기)
## 뽑은 카드 바로 내기는 {"type": "play", "id": 뽑은 카드 id} 로 나간다.

const CardViewScript := preload("res://ui/card_view.gd")
const AvatarViewScript := preload("res://ui/avatar_view.gd")
const DirRingScript := preload("res://ui/dir_ring.gd")
const HandViewScript := preload("res://ui/hand_view.gd")
const CardMap := preload("res://ui/card_map.gd")
const WildPickerScene := preload("res://ui/wild_picker.tscn")
const DrawChoiceScene := preload("res://ui/draw_choice.tscn")
const FxLayerScript := preload("res://ui/fx/table_fx.gd")
const FxEvents := preload("res://ui/fx/fx_events.gd")
const FxTiming := preload("res://ui/fx/fx_timing.gd")
const HanjangScene := preload("res://ui/hanjang_button.tscn")

signal action_requested(action: Dictionary)
## 한장! 행동: {"type": "hanjang"}(낸 사람이 외치기)  {"type": "catch"}(잡았다!)
## 연출(n6): 스냅샷 변화에서 공격·스킵·리버스를 스스로 고른다. 나눠 주기는 start_deal(), 한장! 결과는 show_event() 로 받는다.
##   show_event({"type": "hanjang_called", "seat": 외친 자리})   show_event({"type": "caught", "by": 잡은 자리, "victim": 잡힌 자리})

const COLOR_NAME := ["빨강", "노랑", "초록", "파랑"]
const COLOR_RGB := [Color("e8343a"), Color("f2b51c"), Color("2fa84f"), Color("2f6fe0")]
const DECK_POS := Vector2(492, 248)
const DISCARD_POS := Vector2(584, 248)
const ME_AVATAR_POS := Vector2(28, 520)
const SLOT := {
	"top": {"avatar": Vector2(470, 28), "cards": Vector2(552, 40)},
	"left": {"avatar": Vector2(36, 250), "cards": Vector2(118, 262)},
	"right": {"avatar": Vector2(800, 250), "cards": Vector2(882, 262)},
}
const LAYOUT := {2: {1: "top"}, 3: {1: "left", 2: "right"}, 4: {1: "left", 2: "top", 3: "right"}}
const FLY_TIME := 0.32
const BACK_STEP := 28  # 상대 뒷면 겹침 간격. 작은 카드 폭 40에서 별이 보이는 최소치
const BACK_MAX := 8

var names: Array = ["나", "하늘", "민트", "체리"]
var faces: Array = [3, 0, 1, 2]
var host_seat := 0

var snap: Dictionary = {}
var hand_view
var wild_picker
var draw_choice
var btn_draw: Button
var fx
var hj_ui

var _opps: Control
var _me_box: Control
var _fx: Control
var _discard_cv
var _discard_border: Panel
var _ring
var _bar: ProgressBar
var _time_label: Label
var _bubble: PanelContainer
var _bubble_label: Label
var _end_label: Label
var _opp_center := {}
var _opp_from := {}
var _flying := 0
var _locked := false
var _shown_color := 0
var _last_from := Vector2.ZERO
var _has_from := false
var _dealing := false
var _deal_wanted := false
var _dealt: Array = []
var _hj_key := ""


func _ready() -> void:
	theme = load("res://ui/theme.tres")
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/bg_tile.png")
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_ring = DirRingScript.new()
	add_child(_ring)

	# 뽑을 더미(두께 표현으로 뒷면 셋을 겹친다)와 버린 더미
	for i in [2, 1, 0]:
		var d = CardViewScript.new()
		add_child(d)
		d.show_back()
		d.position = DECK_POS + Vector2(0, 4 * i)
	_discard_border = Panel.new()
	_discard_border.position = DISCARD_POS - Vector2(5, 5)
	_discard_border.size = Vector2(90, 122)
	_discard_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_discard_border)
	_discard_cv = CardViewScript.new()
	add_child(_discard_cv)
	_discard_cv.position = DISCARD_POS

	_opps = Control.new()
	_opps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_opps)
	_me_box = Control.new()
	_me_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_me_box)

	_bar = ProgressBar.new()
	_bar.position = Vector2(130, 556)
	_bar.size = Vector2(200, 24)
	_bar.show_percentage = false
	_bar.visible = false
	add_child(_bar)
	_time_label = Label.new()
	_time_label.position = Vector2(130, 584)
	_time_label.add_theme_font_size_override("font_size", 18)
	_time_label.modulate = Color(0.7, 0.75, 0.9)
	_time_label.visible = false
	add_child(_time_label)

	hand_view = HandViewScript.new()
	hand_view.position = Vector2(40, 440)
	hand_view.size = Vector2(1152, 208)
	add_child(hand_view)
	hand_view.card_chosen.connect(_on_card_chosen)

	btn_draw = Button.new()
	btn_draw.text = "뽑기"
	btn_draw.position = Vector2(960, 556)
	btn_draw.size = Vector2(160, 58)
	btn_draw.pressed.connect(_on_draw_pressed)
	add_child(btn_draw)

	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label = Label.new()
	_bubble_label.add_theme_font_size_override("font_size", 20)
	_bubble_label.add_theme_color_override("font_color", Color("151a2e"))
	_bubble.add_child(_bubble_label)
	add_child(_bubble)

	_end_label = Label.new()
	_end_label.add_theme_font_size_override("font_size", 48)
	_end_label.add_theme_color_override("font_outline_color", Color("151a2e"))
	_end_label.add_theme_constant_override("outline_size", 12)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.position = Vector2(176, 90)
	_end_label.size = Vector2(800, 70)
	_end_label.visible = false
	_end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_end_label)

	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	hj_ui = HanjangScene.instantiate()
	add_child(hj_ui)
	hj_ui.pressed_action.connect(_on_hanjang_pressed)

	wild_picker = WildPickerScene.instantiate()
	wild_picker.visible = false
	add_child(wild_picker)
	wild_picker.color_chosen.connect(func(c): _emit({"type": "choose_color", "color": c}))
	draw_choice = DrawChoiceScene.instantiate()
	draw_choice.visible = false
	add_child(draw_choice)
	draw_choice.play_now.connect(func(): _emit({"type": "play", "id": int(snap.drawn_id), "color": -1}))
	draw_choice.keep.connect(func(): _emit({"type": "keep"}))

	fx = FxLayerScript.new()
	fx.table = self
	add_child(fx)

	var glow := create_tween().set_loops()
	glow.tween_property(btn_draw, "self_modulate", Color(1.5, 1.7, 1.8), 0.5)
	glow.tween_property(btn_draw, "self_modulate", Color(1.15, 1.3, 1.4), 0.5)
	_glow = glow
	_glow.pause()
	if not snap.is_empty():
		apply_snapshot(snap)

var _glow: Tween


func set_players(p_names: Array, p_faces: Array, p_host := 0) -> void:
	names = p_names
	faces = p_faces
	host_seat = p_host
	if not snap.is_empty():
		_redraw(snap)


## 내 시간 바. n4 가 시간을 재면 남은 초와 전체 초를 여기로 보낸다.
func set_time(left: float, total: float) -> void:
	_bar.max_value = total
	_bar.value = maxf(left, 0.0)
	var sec := int(ceilf(maxf(left, 0.0)))
	_time_label.text = "%d:%02d" % [sec / 60, sec % 60]


func is_playable(card: Dictionary, s: Dictionary) -> bool:
	# rules.gd can_play 와 같은 판정. 시험이 둘의 일치를 확인한다.
	if card.kind == "wild" or card.kind == "wild4":
		return true
	if card.color == s.color:
		return true
	var t: Dictionary = s.top
	if card.kind == "num":
		return t.kind == "num" and t.num == card.num
	return t.kind == card.kind


func apply_snapshot(s: Dictionary) -> void:
	var prev := snap
	snap = s
	_locked = false
	if not is_inside_tree() or _ring == null:
		return
	if _deal_wanted and not _dealing:
		_begin_deal()
	_redraw(s)
	if _dealing or prev.is_empty():
		return
	if prev.top.id != s.top.id:
		_fly_top(prev, s)
	fx.play_all(FxEvents.derive(prev, s))


## 한장! 결과처럼 스냅샷만으로 알 수 없는 연출을 보인다.
func show_event(ev: Dictionary) -> void:
	if fx != null and not snap.is_empty():
		fx.play(ev)


## 다음 스냅샷(이미 있으면 지금 것)으로 나눠 주기 연출을 한다. 방장부터 시계 방향으로 한 장씩 7장.
func start_deal() -> void:
	_deal_wanted = true
	if is_inside_tree() and _ring != null and not snap.is_empty():
		apply_snapshot(snap)


func _begin_deal() -> void:
	_deal_wanted = false
	_dealing = true
	_dealt = []
	for i in snap.n:
		_dealt.append(0)
	var order: Array = []
	for k in snap.n:
		var seat := posmod(host_seat + k, snap.n)
		if snap.alive[seat]:
			order.append(seat)
	var per: int = snap.counts.max() if not snap.counts.is_empty() else 7
	fx.deal(order, per, _on_dealt, _finish_deal)


func _on_dealt(seat: int) -> void:
	if not _dealing:
		return
	_dealt[seat] += 1
	_redraw(snap)


func _finish_deal() -> void:
	_dealing = false
	_redraw(snap)
	_discard_cv.pivot_offset = _discard_cv.card_pixel_size() / 2.0
	_discard_cv.scale = Vector2(0.0, 1.0)
	create_tween().tween_property(_discard_cv, "scale", Vector2.ONE, FxTiming.DEAL_FLIP)


func seat_avatar_pos(seat: int) -> Vector2:
	var rel := posmod(seat - snap.seat, snap.n)
	if rel == 0:
		return ME_AVATAR_POS
	return SLOT[LAYOUT[snap.n][rel]].avatar


## 카드가 날아가 닿는 곳: 내 패 가운데 또는 그 사람의 뒷면 줄 가운데.
func seat_hand_point(seat: int) -> Vector2:
	if seat == snap.seat:
		return Vector2(575, 540)
	return _opp_center.get(seat, Vector2(575, 300))


func _redraw(s: Dictionary) -> void:
	var me: int = s.seat
	var my_turn: bool = s.turn == me and s.phase != "done" and not _dealing
	var pick: bool = my_turn and s.phase == "pick"

	# 날아오는 중에는 이전 맨 위 카드와 색 테두리를 그대로 두고, 내려앉은 뒤 바꾼다.
	if _flying == 0:
		_show_discard(s.top, s.color)
	_discard_cv.visible = not _dealing
	_discard_border.visible = not _dealing
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0, 0, 0, 0)
	bsb.set_border_width_all(5)
	bsb.border_color = COLOR_RGB[_shown_color]
	bsb.set_corner_radius_all(3)
	_discard_border.add_theme_stylebox_override("panel", bsb)
	_ring.clockwise = s.dir > 0

	for c in _opps.get_children():
		_opps.remove_child(c)
		c.queue_free()
	for c in _me_box.get_children():
		_me_box.remove_child(c)
		c.queue_free()
	_opp_center = {}
	_opp_from = {}
	var slots: Dictionary = LAYOUT.get(s.n, {})
	for seat in s.n:
		var rel := posmod(seat - me, s.n)
		var av = AvatarViewScript.new()
		var st = AvatarViewScript.State.NORMAL
		if not s.alive[seat]:
			st = AvatarViewScript.State.GRAY
		elif seat == s.turn and s.phase != "done" and not _dealing:
			st = AvatarViewScript.State.TURN
		if rel == 0:
			_me_box.add_child(av)
			av.position = ME_AVATAR_POS
			av.setup(faces[seat], names[seat], st, seat == host_seat)
			continue
		var slot: Dictionary = SLOT[slots[rel]]
		_opps.add_child(av)
		av.position = slot.avatar
		av.setup(faces[seat], names[seat], st, seat == host_seat)
		var cnt: int = s.counts[seat]
		if _dealing:
			cnt = mini(cnt, _dealt[seat])
		var shown := mini(cnt, BACK_MAX)
		for i in shown:
			var cv = CardViewScript.new()
			_opps.add_child(cv)
			cv.show_back()
			cv.set_card_size(CardViewScript.CardSize.SMALL)
			cv.position = slot.cards + Vector2(BACK_STEP * i, 0)
		var badge := PanelContainer.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("1c2340")
		bs.border_color = Color("3a4a8a")
		bs.set_border_width_all(2)
		bs.set_corner_radius_all(2)
		bs.content_margin_left = 8
		bs.content_margin_right = 8
		bs.content_margin_top = 2
		bs.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", bs)
		var bl := Label.new()
		bl.text = str(cnt)
		bl.add_theme_font_size_override("font_size", 20)
		badge.add_child(bl)
		_opps.add_child(badge)
		badge.position = slot.cards + Vector2(BACK_STEP * maxi(shown - 1, 0) + 52, 8)
		_opp_center[seat] = slot.cards + Vector2(BACK_STEP * maxi(shown - 1, 0) / 2.0 + 20, 28)
		_opp_from[seat] = slot.avatar + Vector2(36, 36)

	# 내 패: 내 차례의 고르는 중에만 솟거나 어두워진다. 그 밖에는 평평하다.
	var ids: Array = []
	var shown_hand: Array = s.hand
	if _dealing:
		shown_hand = s.hand.slice(0, _dealt[me])
	if pick:
		for card in s.hand:
			if is_playable(card, s):
				ids.append(card.id)
	hand_view.set_hand(shown_hand, ids, pick)

	_bar.visible = my_turn and s.phase != "hanjang"
	_time_label.visible = _bar.visible
	btn_draw.disabled = not pick
	var glowing := pick and ids.is_empty()
	btn_draw.self_modulate = Color.WHITE
	if glowing:
		_glow.play()
	else:
		_glow.pause()

	_bubble.visible = pick
	if pick:
		var txt: String = COLOR_NAME[s.color]
		if s.top.kind == "num":
			txt += " 또는 %d" % s.top.num
		elif s.top.kind == "skip":
			txt += " 또는 스킵"
		elif s.top.kind == "rev":
			txt += " 또는 리버스"
		elif s.top.kind == "draw2":
			txt += " 또는 +2"
		_bubble_label.text = txt
		_bubble.reset_size()
		_bubble.position = Vector2(575.0 - _bubble.size.x / 2.0, 418)

	wild_picker.visible = my_turn and s.phase == "color"
	draw_choice.visible = my_turn and s.phase == "drawn"
	if draw_choice.visible:
		for card in s.hand:
			if card.id == s.drawn_id:
				draw_choice.show_drawn(card)

	_end_label.visible = s.phase == "done" and s.winner >= 0
	if _end_label.visible:
		_end_label.text = "%s 승리!" % names[s.winner]

	_redraw_hanjang(s)


func _redraw_hanjang(s: Dictionary) -> void:
	if s.phase != "hanjang" or _dealing or not s.alive[s.seat]:
		_hj_key = ""
		hj_ui.hide_all()
		return
	var mode := "call" if s.hanjang_seat == s.seat else "catch"
	var key := "%s:%d" % [mode, s.hanjang_seat]
	var restart := key != _hj_key
	_hj_key = key
	var total: float = s.get("turn_time", FxTiming.HANJANG_WINDOW)
	hj_ui.show_mode(mode, names[s.hanjang_seat], s.get("time_left", total), total, restart)


func _on_hanjang_pressed(kind: String) -> void:
	if _locked:
		return
	hj_ui.btn.disabled = true
	_emit({"type": "hanjang" if kind == "call" else "catch"})


func _show_discard(top: Dictionary, color: int) -> void:
	_shown_color = color
	_discard_cv.show_card(CardMap.view_color(top), CardMap.view_value(top))


func _fly_top(prev: Dictionary, s: Dictionary) -> void:
	var player: int = prev.turn
	var from := Vector2(575, 560)
	var start_scale := 1.0
	if player == s.seat:
		if _has_from:
			from = _last_from
	elif _opp_from.has(player):
		from = _opp_from[player]
		start_scale = 0.5
	_has_from = false
	var cv = CardViewScript.new()
	_fx.add_child(cv)
	cv.show_card(CardMap.view_color(s.top), CardMap.view_value(s.top))
	cv.pivot_offset = Vector2.ZERO
	var start := from - cv.card_pixel_size() * start_scale / 2.0
	cv.position = start
	cv.scale = Vector2(start_scale, start_scale)
	# 버린 더미 자리는 날아오는 동안 이전 맨 위 카드를 그대로 보인다.
	if _flying == 0:
		_show_discard(prev.top, prev.color)
	_flying += 1
	_redraw_discard_border()
	# 위에서 내려오는 곡선: 뽑을 더미 위를 가로지르지 않는다.
	var ctrl := Vector2(DISCARD_POS.x, 20.0)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var u := 1.0 - t
		cv.position = u * u * start + 2.0 * u * t * ctrl + t * t * DISCARD_POS
		var k := lerpf(start_scale, 1.0, t)
		cv.scale = Vector2(k, k), 0.0, 1.0, FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_flying -= 1
		if _flying == 0:
			_show_discard(snap.top, snap.color)
			_redraw_discard_border())
	tw.tween_property(cv, "scale", Vector2(1.12, 1.12), 0.07)
	tw.tween_property(cv, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(cv.queue_free)


func _redraw_discard_border() -> void:
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0, 0, 0, 0)
	bsb.set_border_width_all(5)
	bsb.border_color = COLOR_RGB[_shown_color]
	bsb.set_corner_radius_all(3)
	_discard_border.add_theme_stylebox_override("panel", bsb)


func _on_card_chosen(card_id: int, from_pos: Vector2) -> void:
	_last_from = from_pos
	_has_from = true
	_emit({"type": "play", "id": card_id, "color": -1})


func _on_draw_pressed() -> void:
	if snap.is_empty() or snap.turn != snap.seat or snap.phase != "pick":
		return
	_emit({"type": "draw"})


func _emit(a: Dictionary) -> void:
	if _locked:
		return
	_locked = true
	action_requested.emit(a)

