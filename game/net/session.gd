extends Node
## 방장 판정 게임 세션 (autoload "Session"). 방장만 n1 엔진을 들고, 접속자는 요청만 보내고 자기 판 상태만 받는다.
##
## 화면(n7)이 쓰는 면:
##   request(kind, a=-1, b=-1) -> rid   kind: "play"(a=패 번호, b=색 또는 -1) "color"(a=색) "draw" "keep" "hanjang" "catch"
##   state_changed(snap: Dictionary)    자기 판 상태. Rules.snapshot_for 형태 + time_left(남은 초) + turn_time(전체 초)
##   request_refused(rid, reason)       방장이 요청을 거절했을 때 — 화면은 입력 잠금을 풀 수 있다
##   player_left(seat, name)            판 중 누가 나갔을 때
##   ended(ranks: Array)                판이 끝났을 때
## 시험 인자: --autoplay  --seed=N  --cheat  --turn-time=초(기본 20)  --hj-time=초(기본 3)

signal state_changed(snap: Dictionary)
signal request_refused(rid: int, reason: String)
signal player_left(seat: int, who: String)
signal ended(ranks: Array)
signal event(ev: Dictionary)  ## 한장! 외침·잡았다! 처럼 상태만으로 알 수 없는 사건 (판 상태 뒤에 도착)

const Rules := preload("res://rules/rules.gd")
const TURN_TIME := 20.0
const HJ_TIME := 3.0
const HJ_GRACE := 0.3  ## 한장! 창이 닫힌 뒤 네트워크로 늦게 닿는 요청을 받아 주는 여유
const FxTiming := preload("res://ui/fx/fx_timing.gd")

var engine: Rules
var seats: Array = []
var my_seat := -1
var last_snap: Dictionary = {}
var turn_time := TURN_TIME
var hj_time := HJ_TIME

var _opts := {}
var _autoplay := false
var _cheat := false
var _seed := -1
var _rid := 0
var _last_req: Array = []
var _seen := {}
var _deadline := 0.0
var _deal_until := 0.0
var _running := false
var _serial := 0
var _end_reported := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		_opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_autoplay = _opts.has("autoplay")
	_cheat = _opts.has("cheat")
	_seed = int(_opts.get("seed", -1))
	turn_time = float(_opts.get("turn-time", TURN_TIME))
	hj_time = float(_opts.get("hj-time", HJ_TIME))
	Room.game_started.connect(_on_game_started)
	Room.peer_left.connect(_on_peer_left)


func _on_game_started(p_seats: Array) -> void:
	seats = p_seats
	_end_reported = false
	last_snap = {}
	my_seat = -1
	for i in seats.size():
		if seats[i].peer == multiplayer.get_unique_id():
			my_seat = i
	_rng.seed = (_seed if _seed >= 0 else 1) * 131 + my_seat
	if Room.is_host():
		_start_host.call_deferred()


# ---------- 방장 ----------

func _start_host() -> void:
	await get_tree().create_timer(0.3).timeout  ## 접속자가 시작 신호를 먼저 받도록 잠깐 둔다
	engine = Rules.new()
	engine.setup(seats.size(), _seed)
	_seen = {}
	for i in seats.size():  ## 0.3초 사이에 나간 자리는 판이 시작될 때 바로 나간 처리
		if seats[i].get("gone", false):
			engine.leave(i)
	_running = true
	print("SESSION_START n=", seats.size(), " seed=", _seed)
	_deadline = INF  ## 나눠 주기 연출이 끝난 뒤부터 첫 차례 시간을 잰다
	var deal := FxTiming.deal_total(seats.size(), engine.HAND_SIZE)
	_deal_until = Time.get_ticks_msec() / 1000.0 + deal
	_push()
	await get_tree().create_timer(deal).timeout
	if engine == null or not _running or engine.phase == "done":
		return
	_mark_deadline()
	_push()  ## 연출이 끝난 뒤 한 번 더 보내 시간 표시와 자동 플레이가 이때부터 시작한다


func seat_of(peer: int) -> int:
	for i in seats.size():
		if seats[i].peer == peer:
			return i
	return -1


func _process(_dt: float) -> void:
	if not (_running and Room.is_host()) or engine == null or engine.phase == "done":
		return
	if Time.get_ticks_msec() / 1000.0 >= _deadline:
		_on_timeout()


func _mark_deadline() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_deadline = now + (hj_time + HJ_GRACE if engine.phase == "hanjang" else turn_time)


func _on_timeout() -> void:
	var s := engine.turn
	match engine.phase:
		"pick":
			engine.draw(s)
			print("AUTO_DRAW seat=", s)
			if engine.phase == "drawn":
				engine.keep_drawn(s)
				print("AUTO_KEEP seat=", s)
		"drawn":
			engine.keep_drawn(s)
			print("AUTO_KEEP seat=", s)
		"color":
			var c := engine.auto_color(s)
			engine.choose_color(s, c)
			print("AUTO_COLOR seat=", s, " color=", c)
		"hanjang":
			engine.close_hanjang()
			print("HJ_WINDOW_CLOSED")
	_after_change()


func _after_change() -> void:
	_mark_deadline()
	_push()


func _push() -> void:
	if engine == null:
		return
	var left := 0.0 if _deadline == INF else maxf(0.0, _deadline - Time.get_ticks_msec() / 1000.0 - (HJ_GRACE if engine.phase == "hanjang" else 0.0))
	if _deadline == INF:
		left = turn_time
	for i in seats.size():
		if not engine.alive[i]:
			continue
		var snap := engine.snapshot_for(i)
		snap["time_left"] = left
		snap["turn_time"] = hj_time if engine.phase == "hanjang" else turn_time
		var p: int = seats[i].peer
		if p == multiplayer.get_unique_id():
			_receive(snap)
		else:
			_state.rpc_id(p, snap)


func _handle(peer: int, rid: int, kind: String, a: int, b: int) -> void:
	var seat := seat_of(peer)
	if engine == null or seat < 0:
		print("IGNORED seat=", seat, " rid=", rid, " kind=", kind, " reason=세션 밖")
		return
	if rid <= int(_seen.get(seat, 0)):
		print("IGNORED seat=", seat, " rid=", rid, " kind=", kind, " reason=같은 요청 두 번")
		return
	_seen[seat] = rid
	if Time.get_ticks_msec() / 1000.0 < _deal_until:
		print("IGNORED seat=", seat, " rid=", rid, " kind=", kind, " reason=나눠 주는 중")
		_refuse(peer, rid, "나눠 주는 중이에요")
		return
	var r: Dictionary
	match kind:
		"play": r = engine.play(seat, a, b)
		"color": r = engine.choose_color(seat, a)
		"draw": r = engine.draw(seat)
		"keep": r = engine.keep_drawn(seat)
		"hanjang": r = engine.call_hanjang(seat)
		"catch": r = engine.catch_hanjang(seat)
		_: r = {"ok": false, "reason": "모르는 요청"}
	if r.ok:
		print("ACCEPT seat=", seat, " rid=", rid, " kind=", kind)
		_after_change()
		if kind == "hanjang":
			_send_event({"type": "hanjang_called", "seat": seat})
		elif kind == "catch":
			_send_event({"type": "caught", "by": seat, "victim": r.victim})
	else:
		print("IGNORED seat=", seat, " rid=", rid, " kind=", kind, " reason=", r.reason)
		_refuse(peer, rid, r.reason)


func _send_event(ev: Dictionary) -> void:
	for i in seats.size():
		if not engine.alive[i]:
			continue
		var p: int = seats[i].peer
		if p == multiplayer.get_unique_id():
			event.emit(ev)
		else:
			_event.rpc_id(p, ev)


func _refuse(peer: int, rid: int, reason: String) -> void:
	if peer == multiplayer.get_unique_id():
		request_refused.emit(rid, reason)
	else:
		_refused.rpc_id(peer, rid, reason)


func _on_peer_left(peer: int) -> void:
	var seat := seat_of(peer)
	if engine == null or seat < 0 or not engine.alive[seat]:
		return
	var who: String = seats[seat].name
	var before := [engine.turn, engine.phase]
	engine.leave(seat)
	print("PLAYER_LEFT seat=", seat, " ", who)
	for i in seats.size():
		if engine.alive[i] and seats[i].peer != multiplayer.get_unique_id():
			_left.rpc_id(seats[i].peer, seat, who)
	player_left.emit(seat, who)
	if before == [engine.turn, engine.phase]:
		_push()  ## 차례가 그대로면 남은 시간을 새로 재지 않는다
	else:
		_after_change()


# ---------- 요청 보내기 (방장·접속자 공통) ----------

func request(kind: String, a: int = -1, b: int = -1) -> int:
	_rid += 1
	_send(_rid, kind, a, b)
	_last_req = [_rid, kind, a, b]
	return _rid


func _send(rid: int, kind: String, a: int, b: int) -> void:
	if Room.is_host():
		_handle(multiplayer.get_unique_id(), rid, kind, a, b)
	else:
		_request.rpc_id(1, rid, kind, a, b)


## 자리는 보낸 값이 아니라 보낸 peer id로만 정한다.
@rpc("any_peer", "call_remote", "reliable")
func _request(rid: int, kind: String, a: int, b: int) -> void:
	if Room.is_host():
		_handle(multiplayer.get_remote_sender_id(), rid, kind, a, b)


@rpc("authority", "call_remote", "reliable")
func _state(snap: Dictionary) -> void:
	_receive(snap)


@rpc("authority", "call_remote", "reliable")
func _event(ev: Dictionary) -> void:
	event.emit(ev)


@rpc("authority", "call_remote", "reliable")
func _refused(rid: int, reason: String) -> void:
	request_refused.emit(rid, reason)


@rpc("authority", "call_remote", "reliable")
func _left(seat: int, who: String) -> void:
	print("PLAYER_LEFT seat=", seat, " ", who)
	player_left.emit(seat, who)


# ---------- 받기 ----------

func _receive(snap: Dictionary) -> void:
	last_snap = snap
	my_seat = snap.seat
	_serial += 1
	var leak := _leaks(snap)
	if leak != "":
		print("LEAK seat=", my_seat, " ", leak)
	print("MYHAND seat=", my_seat, " ", _codes(snap.hand))
	state_changed.emit(snap)
	if snap.phase == "done":
		if not _end_reported:
			_end_reported = true
			print("RESULT winner=", snap.winner, " ranks=", snap.ranks)
			ended.emit(snap.ranks)
			if _autoplay and not _opts.has("keep-open"):
				get_tree().create_timer(1.5).timeout.connect(get_tree().quit)
		return
	if _autoplay:
		_autoplay_decide(snap)
	if _cheat:
		_cheat_maybe(snap)


## 받은 상태에서 hand·top 밖에 카드가 있으면 남의 패가 샌 것이다.
func _leaks(snap: Dictionary) -> String:
	for k in snap:
		if k in ["hand", "top"]:
			continue
		if _has_card(snap[k]):
			return str(k)
	return ""


func _has_card(v) -> bool:
	if v is Dictionary:
		if v.has("kind"):
			return true
		for k in v:
			if _has_card(v[k]):
				return true
	elif v is Array:
		for x in v:
			if _has_card(x):
				return true
	return false


func _codes(hand: Array) -> String:
	var out := []
	for c in hand:
		out.append("%s%d" % [c.kind, c.color] + ("" if c.num < 0 else ":%d" % c.num))
	return " ".join(out)


# ---------- 시험용 자동 플레이 ----------

func _can_play(snap: Dictionary, c: Dictionary) -> bool:
	if c.kind == "wild" or c.kind == "wild4":
		return true
	if c.color == snap.color:
		return true
	var t: Dictionary = snap.top
	if c.kind == "num":
		return t.kind == "num" and t.num == c.num
	return t.kind == c.kind


func _best_color(hand: Array) -> int:
	var cnt := [0, 0, 0, 0]
	for c in hand:
		if c.color >= 0:
			cnt[c.color] += 1
	var best := 0
	for i in range(1, 4):
		if cnt[i] > cnt[best]:
			best = i
	return best


func _autoplay_decide(snap: Dictionary) -> void:
	var me: int = snap.seat
	var serial := _serial
	var delay := 0.05 + _rng.randf() * 0.1
	var act := Callable()
	if snap.phase == "hanjang":
		if snap.hanjang_seat == me:
			if _rng.randf() < 0.7:  ## 가끔 한장!을 잊는다
				act = func(): request("hanjang")
		elif _rng.randf() < 0.6:
			delay = 0.5
			act = func(): request("catch")
	elif snap.turn == me:
		if _rng.randf() < 0.15:  ## 가끔 멍하니 있어 시간이 다 된다
			return
		act = func(): _autoplay_turn(snap)
	if act.is_valid():
		get_tree().create_timer(delay).timeout.connect(func():
			if serial == _serial:
				act.call())


func _autoplay_turn(snap: Dictionary) -> void:
	var hand: Array = snap.hand
	match snap.phase:
		"pick":
			for i in hand.size():
				if _can_play(snap, hand[i]):
					var wild: bool = hand[i].kind.begins_with("wild")
					request("play", i, -1 if (wild and _rng.randf() < 0.5) else _best_color(hand))
					return
			request("draw")
		"drawn":
			for i in hand.size():
				if hand[i].id == snap.drawn_id:
					request("play", i, _best_color(hand))
					return
			request("keep")
		"color":
			request("color", _best_color(hand))


func _cheat_maybe(snap: Dictionary) -> void:
	if _rng.randf() > 0.5:
		return
	var me: int = snap.seat
	var pick := _rng.randi_range(0, 3)
	var rid := 0
	var kind := ""
	if pick == 0 and not _last_req.is_empty():
		rid = _last_req[0]
		kind = _last_req[1]
		print("CHEAT_SENT seat=", me, " rid=", rid, " kind=", kind)
		_send(rid, kind, _last_req[2], _last_req[3])
		return
	if snap.turn != me or snap.phase == "hanjang":
		kind = ["play", "draw", "keep", "color"][pick]
		rid = request(kind, 0, 0)
	elif pick == 1:
		kind = "hanjang"
		rid = request(kind)
	else:
		kind = "play"
		rid = request(kind, 99, 0)
	print("CHEAT_SENT seat=", me, " rid=", rid, " kind=", kind)
