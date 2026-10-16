extends Control
## 판 화면 위의 연출 층. 판 상태는 table.gd 가 그리고, 이 층은 그 위에 얹는 장식만 한다.
## 연출이 끝나지 않아도 판 상태는 이미 새 상태로 그려져 있다.

const FxTiming := preload("res://ui/fx/fx_timing.gd")
const CardViewScript := preload("res://ui/card_view.gd")

const RED := Color("e8343a")
const YELLOW := Color("f2b51c")
const NAVY := Color("151a2e")
const CYAN := Color("52e0ee")
const RING_BLUE := Color("4a64d8")

var table
var active := 0  # 지금 돌고 있는 연출 수. 시험이 끝났는지 볼 때 쓴다


class StopSign extends Control:
	func _init() -> void:
		size = Vector2(88, 88)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		draw_arc(c, 40.0, 0.0, TAU, 40, Color("e8343a"), 8.0, true)
		draw_line(c + Vector2(-28, 28), c + Vector2(28, -28), Color("e8343a"), 8.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _track(tw: Tween) -> void:
	active += 1
	tw.finished.connect(func(): active -= 1)


func play_all(events: Array) -> void:
	for ev in events:
		play(ev)


func play(ev: Dictionary) -> void:
	match ev.type:
		"attack":
			_attack(ev)
		"skip":
			_skip(ev)
		"reverse":
			_reverse(ev)
		"hanjang_called":
			banner("%s: 1장 남음!" % table.names[ev.seat], NAVY, YELLOW, Color.WHITE, Vector2(576, 425), FxTiming.CALL_HOLD, 30)
		"caught":
			_caught(ev)


func _name_of(seat: int) -> String:
	return table.names[seat]


static func ga(who: String) -> String:
	if who.is_empty():
		return "가"
	var code := who.unicode_at(who.length() - 1)
	if code >= 0xAC00 and code <= 0xD7A3 and (code - 0xAC00) % 28 != 0:
		return "이"
	return "가"


func _attack(ev: Dictionary) -> void:
	var me: int = table.snap.seat
	var v: int = ev.victim
	var txt := "%s의 공격! %d장 받아요" % [_name_of(ev.by), ev.amount]
	var stamp_at := Vector2(200, 440)
	if v != me:
		txt = "%s의 공격! %s %d장" % [_name_of(ev.by), _name_of(v), ev.amount]
		stamp_at = table.seat_avatar_pos(v) + Vector2(44, 150)
		stamp_at.y = clampf(stamp_at.y, 90.0, 400.0)
	stamp("+%d" % ev.amount, RED, stamp_at, 96 if v == me else 64, FxTiming.STAMP_HOLD)
	banner(txt, NAVY, RED, Color.WHITE, Vector2(780, 400) if v == me else Vector2(576, 372), FxTiming.BANNER_HOLD, 22)
	cards_to(v, ev.amount)
	shake(v)


func _skip(ev: Dictionary) -> void:
	var at: Vector2 = table.seat_avatar_pos(ev.seat)
	var stop := StopSign.new()
	add_child(stop)
	stop.position = at
	stop.pivot_offset = stop.size / 2.0
	stop.scale = Vector2(2.0, 2.0)
	stop.modulate.a = 0.0
	var tw := create_tween()
	_track(tw)
	tw.set_parallel(true)
	tw.tween_property(stop, "scale", Vector2.ONE, FxTiming.STAMP_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stop, "modulate:a", 1.0, 0.1)
	tw.chain().tween_interval(FxTiming.SKIP_HOLD)
	tw.chain().tween_property(stop, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(stop.queue_free)
	banner("건너뜀!", Color.WHITE, Color.WHITE, NAVY, at + Vector2(44, -26), FxTiming.SKIP_HOLD, 20)


func _reverse(_ev: Dictionary) -> void:
	var ring = table._ring
	var tw := create_tween()
	_track(tw)
	tw.tween_callback(func(): ring.color = YELLOW)
	tw.tween_interval(FxTiming.REVERSE_HOLD)
	tw.tween_method(func(t: float): ring.color = YELLOW.lerp(RING_BLUE, t), 0.0, 1.0, FxTiming.REVERSE_BACK)
	stamp("반대로!", YELLOW, Vector2(690, 150), 64, FxTiming.STAMP_HOLD)


func _caught(ev: Dictionary) -> void:
	var me: int = table.snap.seat
	var by_txt := ""
	if ev.by == me:
		by_txt = "내가 잡았다!"
	elif ev.by >= 0:
		var nm := _name_of(ev.by)
		by_txt = "%s%s 잡았다!" % [nm, ga(nm)]
	else:
		by_txt = "잡았다!"
	banner("%s %s +2장" % [by_txt, _name_of(ev.victim)], NAVY, RED, Color.WHITE, Vector2(576, 425), FxTiming.CATCH_HOLD, 26)
	cards_to(ev.victim, 2)
	shake(ev.victim)


## 큰 글자가 쾅 찍힌다.
func stamp(text: String, color: Color, center: Vector2, font_size: int, hold: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", NAVY)
	l.add_theme_constant_override("outline_size", 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(420, font_size * 1.4)
	l.position = center - l.size / 2.0
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(2.6, 2.6)
	l.modulate.a = 0.0
	add_child(l)
	var tw := create_tween()
	_track(tw)
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, FxTiming.STAMP_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.1)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(l.queue_free)
	return l


## 글 상자. hold가 0보다 작으면 남겨 두고 부른 쪽이 지운다.
func banner(text: String, bg: Color, border: Color, fg: Color, center: Vector2, hold: float, font_size := 22) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", fg)
	p.add_child(l)
	add_child(p)
	p.reset_size()
	p.position = center - p.size / 2.0
	p.modulate.a = 0.0
	var tw := create_tween()
	_track(tw)
	tw.tween_property(p, "modulate:a", 1.0, 0.12)
	if hold >= 0.0:
		tw.tween_interval(hold)
		tw.tween_property(p, "modulate:a", 0.0, 0.25)
		tw.tween_callback(p.queue_free)
	return p


## 맞은 아바타가 빨갛게 흔들린다. 진짜 아바타 위에 붉은 복사본을 얹어 흔든다.
func shake(seat: int) -> void:
	var at: Vector2 = table.seat_avatar_pos(seat)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.position = at
	var frame := TextureRect.new()
	frame.texture = load("res://assets/ui/avatar_frame_normal.png")
	frame.size = Vector2(88, 88)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := TextureRect.new()
	face.texture = load("res://assets/avatars/face_%d.png" % posmod(table.faces[seat], 4))
	face.position = Vector2(12, 12)
	face.size = Vector2(64, 64)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	box.add_child(face)
	box.modulate = Color(1.0, 0.3, 0.3, 1.0)
	add_child(box)
	var tw := create_tween()
	_track(tw)
	tw.tween_method(func(t: float):
		box.position = at + Vector2(sin(t * 48.0) * 7.0 * (1.0 - t), 0)
		box.modulate.a = 1.0 - maxf(t - 0.6, 0.0) / 0.4, 0.0, 1.0, FxTiming.SHAKE)
	tw.tween_callback(box.queue_free)


func _fly_step(t: float, cv, seat: int, end_scale: float) -> void:
	cv.visible = true
	var to: Vector2 = table.seat_hand_point(seat) - cv.card_pixel_size() * end_scale / 2.0
	cv.position = Vector2(table.DECK_POS).lerp(to, t)
	var k := lerpf(1.0, end_scale, t)
	cv.scale = Vector2(k, k)


func _new_back() -> Control:
	var cv = CardViewScript.new()
	add_child(cv)
	cv.show_back()
	cv.pivot_offset = Vector2.ZERO
	cv.visible = false
	cv.position = table.DECK_POS
	return cv


## 더미에서 카드 n장이 그 자리 사람에게 날아간다.
func cards_to(seat: int, n: int) -> void:
	var end_scale := 1.0 if seat == table.snap.seat else 0.5
	for i in n:
		var cv = _new_back()
		var tw := create_tween()
		_track(tw)
		tw.tween_method(_fly_step.bind(cv, seat, end_scale), 0.0, 1.0, FxTiming.DRAW_FLY).set_delay(i * FxTiming.DRAW_STEP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(cv.queue_free)


## 나눠 주기. order 의 자리 순서로 한 장씩 per 장 돌린다. 한 장이 내려앉을 때마다 on_land(seat), 끝나면 on_done().
func deal(order: Array, per: int, on_land: Callable, on_done: Callable) -> void:
	var cap := banner("%d장씩 나눠요" % per, NAVY, CYAN, Color.WHITE, Vector2(576, 608), -1.0, 22)
	var total := per * order.size()
	for k in total:
		var seat: int = order[k % order.size()]
		var end_scale := 1.0 if seat == table.snap.seat else 0.5
		var cv = _new_back()
		var tw := create_tween()
		_track(tw)
		tw.tween_method(_fly_step.bind(cv, seat, end_scale), 0.0, 1.0, FxTiming.DEAL_FLY).set_delay(k * FxTiming.DEAL_STEP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			cv.queue_free()
			on_land.call(seat)
			if k == total - 1:
				cap.queue_free()
				on_done.call())


## 장면 14: 접속자가 나갔다. 말풍선, 위쪽 알림, 카드가 더미로 돌아간다.
## 방 주인이 나가서 다음 사람에게 넘어갔을 때 위쪽 알림.
func owner_fx(who: String) -> void:
	banner("%s님이 방 주인이 됐어요" % who, NAVY, RED, Color.WHITE, Vector2(576, 70), FxTiming.LEAVE_HOLD + 1.0, 22)


func disconnect_fx(seat: int, cards: int, who: String) -> void:
	var at: Vector2 = table.seat_avatar_pos(seat)
	banner("연결 끊김", Color.WHITE, Color.WHITE, NAVY, at + Vector2(44, -22), FxTiming.LEAVE_HOLD, 20)
	banner("%s%s 나갔어요 · 카드 %d장은 더미로" % [who, ga(who), cards], NAVY, RED, Color.WHITE, Vector2(576, 22), FxTiming.LEAVE_HOLD, 22)
	var from: Vector2 = table.seat_hand_point(seat)
	for i in mini(cards, 8):
		var cv = _new_back()
		var tw := create_tween()
		_track(tw)
		tw.tween_method(func(t: float):
			cv.visible = true
			var start: Vector2 = from - cv.card_pixel_size() * 0.25
			cv.position = start.lerp(Vector2(table.DECK_POS), t)
			var k := lerpf(0.5, 1.0, t)
			cv.scale = Vector2(k, k), 0.0, 1.0, FxTiming.DRAW_FLY).set_delay(i * FxTiming.DRAW_STEP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(cv.queue_free)
