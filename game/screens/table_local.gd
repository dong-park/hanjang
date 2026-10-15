extends Control
## 혼자 시험용 드라이버. n1 엔진을 직접 돌리고 판 화면에는 스냅샷만 준다.
## 나는 자리 0이고 나머지 세 자리는 자동으로 낸다. 실행: -- --local [--seed=N]

const Rules := preload("res://rules/rules.gd")
const TableScene := preload("res://screens/table.tscn")

const TURN_SECONDS := 15.0

var rules
var table
var bot_delay := 0.9
var _turn_time := 0.0
var _bot_wait := 0.0


func _ready() -> void:
	var seed_value := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
	rules = Rules.new()
	rules.setup(4, seed_value)
	table = TableScene.instantiate()
	add_child(table)
	table.action_requested.connect(_on_action)
	push()


func push() -> void:
	_settle_hanjang()
	_turn_time = 0.0
	_bot_wait = 0.0
	table.apply_snapshot(rules.snapshot_for(0))


# 한장! 외치기 화면은 n6 몫이다. 여기서는 낸 사람이 바로 외친 것으로 넘긴다.
func _settle_hanjang() -> void:
	if rules.phase == "hanjang":
		rules.call_hanjang(rules.hj_seat)


func _on_action(a: Dictionary) -> void:
	var res := apply_action(0, a)
	print("LOCAL action ", a.type, " ok=", res.ok, " ", res.reason)
	push()


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
	return {"ok": false, "reason": "모르는 행동"}


func _index_of(seat: int, card_id: int) -> int:
	for i in rules.hands[seat].size():
		if rules.hands[seat][i].id == card_id:
			return i
	return -1


func _process(delta: float) -> void:
	if rules.phase == "done":
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


## 봇 한 걸음. 낼 수 있는 카드 중 와일드가 아닌 것을 먼저 낸다.
func bot_step() -> void:
	var seat: int = rules.turn
	if seat == 0:
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
