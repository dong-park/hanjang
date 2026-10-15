extends Control
## 판 화면을 방 세션(Session)에 묶는다. 세션이 보낸 판 상태는 apply_snapshot 으로, 화면의 행동은 세션 요청으로 나간다.
## 판이 끝나면 잠깐 뒤 finished 를 보내 결과 화면으로 넘어가게 한다.

signal finished

const TableScene := preload("res://screens/table.tscn")
const RESULT_DELAY := 2.2

var table
var _session
var _left_at := 0.0
var _total := 20.0
var _timed := false
var _kinds := {}  ## 보낸 요청 번호 -> 종류. 거절된 한장!·잡았다! 버튼을 내릴 때 쓴다


func _ready() -> void:
	_session = get_node("/root/Session")
	table = TableScene.instantiate()
	add_child(table)
	var names: Array = []
	var faces: Array = []
	for s in _session.seats:
		names.append(s.name)
		faces.append(s.face)
	table.set_players(names, faces, 0)
	table.start_deal()
	table.action_requested.connect(_on_action)
	_session.state_changed.connect(_on_state)
	_session.request_refused.connect(_on_refused)
	_session.player_left.connect(_on_player_left)
	_session.event.connect(table.show_event)
	_session.ended.connect(_on_ended)
	if not _session.last_snap.is_empty():
		_on_state(_session.last_snap)


func _exit_tree() -> void:
	for pair in [[_session.state_changed, _on_state], [_session.request_refused, _on_refused],
			[_session.player_left, _on_player_left], [_session.event, table.show_event], [_session.ended, _on_ended]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _process(_dt: float) -> void:
	if _timed and table.snap.get("phase", "") != "hanjang":
		table.set_time(maxf(_left_at - Time.get_ticks_msec() / 1000.0, 0.0), _total)


func _on_state(snap: Dictionary) -> void:
	_total = snap.get("turn_time", 20.0)
	_left_at = Time.get_ticks_msec() / 1000.0 + snap.get("time_left", _total)
	_timed = true
	table.apply_snapshot(snap)


func _on_action(a: Dictionary) -> void:
	match a.type:
		"play":
			var idx := _index_of(int(a.id))
			if idx < 0:
				table.unlock()
				return
			_kinds[_session.request("play", idx, int(a.get("color", -1)))] = "play"
		"choose_color":
			_kinds[_session.request("color", int(a.color))] = "color"
		_:
			_kinds[_session.request(a.type)] = a.type


func _index_of(card_id: int) -> int:
	var hand: Array = table.snap.get("hand", [])
	for i in hand.size():
		if hand[i].id == card_id:
			return i
	return -1


## 방장이 거절하면 입력 잠금을 푼다.
func _on_refused(rid: int, _reason: String) -> void:
	table.unlock()
	if _kinds.get(rid, "") in ["hanjang", "catch"]:  ## 창이 이미 닫혔다: 한장! 버튼을 내린다
		table.hj_ui.hide_all()


## 장면 14: 나간 사람 말풍선, 카드가 더미로, 위쪽 알림. 아바타 회색은 곧 오는 판 상태가 그린다.
func _on_player_left(seat: int, who: String) -> void:
	var counts: Array = table.snap.get("counts", [])
	var cnt: int = counts[seat] if seat < counts.size() else 0
	print("DISCONNECT_FX seat=", seat, " cards=", cnt)
	table.fx.disconnect_fx(seat, cnt, who)


func _on_ended(_ranks: Array) -> void:
	await get_tree().create_timer(RESULT_DELAY).timeout
	finished.emit()
