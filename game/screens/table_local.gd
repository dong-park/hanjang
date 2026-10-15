extends Control
## 혼자 시험용 드라이버. n1 엔진을 직접 돌리고 판 화면에는 스냅샷만 준다.
## 나는 자리 0이고 나머지 세 자리는 자동으로 낸다. 실행: -- --local [--seed=N]

const Rules := preload("res://rules/rules.gd")
const TableScene := preload("res://screens/table.tscn")

const TURN_SECONDS := 15.0
const HJ_SECONDS := 3.0

var rules
var table
var bot_delay := 0.9
var _turn_time := 0.0
var _bot_wait := 0.0
var _hj_wait := 0.0
## 시험 손잡이: 봇이 낸 1장 남음에 봇이 외치지 않는다 / 봇 하늘(자리1)이 내가 낸 한장!을 잡는다.
var bot_forgets := false
var bot_catches := false


func _ready() -> void:
	var seed_value := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
	var want_deal := OS.get_cmdline_user_args().has("--deal")
	rules = Rules.new()
	rules.setup(4, seed_value)
	table = TableScene.instantiate()
	add_child(table)
	table.action_requested.connect(_on_action)
	if want_deal:
		table.start_deal()
	push()


func push() -> void:
	_turn_time = 0.0
	_bot_wait = 0.0
	var s: Dictionary = rules.snapshot_for(0)
	if rules.phase == "hanjang":
		s["turn_time"] = HJ_SECONDS
		s["time_left"] = maxf(HJ_SECONDS - _hj_wait, 0.0)
	else:
		_hj_wait = 0.0
	table.apply_snapshot(s)


## 시험용: 열린 한장! 창을 낸 사람이 외친 것으로 닫는다.
func settle_hanjang() -> void:
	if rules.phase == "hanjang":
		var who: int = rules.hj_seat
		rules.call_hanjang(who)
		push()
		table.show_event({"type": "hanjang_called", "seat": who})


func _on_action(a: Dictionary) -> void:
	var res := apply_action(0, a)
	print("LOCAL action ", a.type, " ok=", res.ok, " ", res.reason)
	push_with_event()


func apply_action(seat: int, a: Dictionary) -> Dictionary:
	match a.type:
		"play":
			return rules.play(seat, _index_of(seat, a.id), a.get("color", -1))
		"choose_color":
			return rules.choose_color(seat, a.color)
		"draw":
			return rules.draw(seat)
		"keep":
			return rules.keep_drawn(seat)
		"hanjang":
			var r1: Dictionary = rules.call_hanjang(seat)
			if r1.ok:
				_after_push_event({"type": "hanjang_called", "seat": seat})
			return r1
		"catch":
			var victim: int = rules.hj_seat
			var r2: Dictionary = rules.catch_hanjang(seat)
			if r2.ok:
				_after_push_event({"type": "caught", "by": seat, "victim": victim})
			return r2
	return {"ok": false, "reason": "모르는 행동"}


var _pending_event := {}


func _after_push_event(ev: Dictionary) -> void:
	_pending_event = ev


func _index_of(seat: int, card_id: int) -> int:
	for i in rules.hands[seat].size():
		if rules.hands[seat][i].id == card_id:
			return i
	return -1


func _process(delta: float) -> void:
	if rules.phase == "done" or table.is_dealing():
		return
	if rules.phase == "hanjang":
		_hj_wait += delta
		if rules.hj_seat != 0 and not bot_forgets and _hj_wait >= 1.0:
			apply_action(rules.hj_seat, {"type": "hanjang"})
			push_with_event()
		elif rules.hj_seat == 0 and bot_catches and _hj_wait >= 1.2:
			apply_action(1, {"type": "catch"})
			push_with_event()
		elif _hj_wait >= HJ_SECONDS:
			rules.close_hanjang()
			push()
		return
	if rules.turn == 0:
		_turn_time += delta
		table.set_time(TURN_SECONDS - _turn_time, TURN_SECONDS)
		if _turn_time >= TURN_SECONDS:
			_timeout()
	else:
		_bot_wait += delta
		if _bot_wait >= bot_delay:
			bot_step()


func _timeout() -> void:
	match rules.phase:
		"pick":
			rules.draw(0)
		"color":
			rules.choose_color(0, rules.auto_color(0))
		"drawn":
			rules.keep_drawn(0)
	push()


func push_with_event() -> void:
	var ev := _pending_event
	_pending_event = {}
	push()
	if not ev.is_empty():
		table.show_event(ev)


## 봇 한 걸음. 낼 수 있는 카드 중 와일드가 아닌 것을 먼저 낸다.
func bot_step() -> void:
	var seat: int = rules.turn
	if seat == 0 or rules.phase == "hanjang":
		return
	match rules.phase:
		"pick":
			var pick := -1
			for i in rules.hands[seat].size():
				var c: Dictionary = rules.hands[seat][i]
				if rules.can_play(c) and (pick < 0 or rules.hands[seat][pick].color < 0):
					pick = i
			if pick < 0:
				rules.draw(seat)
			else:
				rules.play(seat, pick, rules.auto_color(seat))
		"drawn":
			rules.play(seat, rules.drawn_idx, rules.auto_color(seat))
		"color":
			rules.choose_color(seat, rules.auto_color(seat))
	push()
