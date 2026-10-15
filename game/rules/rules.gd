extends RefCounted
## 한장! 규칙 엔진 — 화면·네트워크 없이 한 판의 모든 판정을 한다. 시간 재기는 하지 않는다(n4 몫).
##
## 카드: {id:int(덱에서 유일), color:int, kind:String, num:int}
##   color 0 빨강 1 노랑 2 초록 3 파랑, -1 와일드류.  kind "num" "skip" "rev" "draw2" "wild" "wild4".
##   num 은 kind=="num" 일 때만 뜻이 있다(아니면 -1).
##
## 요청 함수는 모두 {ok:bool, reason:String, ...}를 돌려준다. 안 되는 요청은 상태를 바꾸지 않는다.
##   play(seat, idx, color=-1)  choose_color(seat, color)  draw(seat)  keep_drawn(seat)
##   call_hanjang(seat)  catch_hanjang(by_seat)  close_hanjang()  leave(seat)
##   auto_color(seat) / ranking() / snapshot_for(seat)
##
## 차례 단계 phase: "pick" 고르는 중, "color" 색 고르는 중, "drawn" 뽑은 카드 고르는 중,
##   "hanjang" 한장! 판정 중(창이 열린 동안 내기·뽑기는 거절), "done" 판 끝.
##
## snapshot_for(seat) 형태 — 남의 패 카드 값은 들어가지 않는다:
##   {seat:int, n:int, top:카드, color:int, counts:[자리별 장수], alive:[자리별 접속 bool],
##    turn:int, dir:int(1|-1), phase:String, hanjang_seat:int(-1이면 없음),
##    hand:[그 자리의 패], drawn_id:int(뽑은 카드 고르는 중일 때 그 자리만, 아니면 -1),
##    deck_count:int, winner:int(-1이면 없음), ranks:[자리별 등수, 0이면 등수 없음]}

const HAND_SIZE := 7

var n := 0
var hands: Array = []
var alive: Array = []
var deck: Array = []
var discard: Array = []
var turn := 0
var dir := 1
var cur_color := 0
var phase := "pick"
var hj_seat := -1
var drawn_idx := -1
var pending_wild: Dictionary = {}
var winner := -1
var rng := RandomNumberGenerator.new()
var _next_id := 0

func setup(count: int, seed_value: int = -1) -> void:
	n = count
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	hands = []
	alive = []
	for i in n:
		hands.append([])
		alive.append(true)
	deck = build_deck()
	discard = []
	shuffle(deck)
	for r in HAND_SIZE:
		for i in n:
			hands[i].append(deck.pop_back())
	_flip_first()
	turn = 0
	dir = 1
	phase = "pick"
	hj_seat = -1
	drawn_idx = -1
	pending_wild = {}
	winner = -1

func make_card(color: int, kind: String, num: int = -1) -> Dictionary:
	_next_id += 1
	return {"id": _next_id, "color": color, "kind": kind, "num": num}

func build_deck() -> Array:
	var d: Array = []
	for c in 4:
		d.append(make_card(c, "num", 0))
		for v in range(1, 10):
			d.append(make_card(c, "num", v))
			d.append(make_card(c, "num", v))
		for k in ["skip", "rev", "draw2"]:
			d.append(make_card(c, k))
			d.append(make_card(c, k))
	for i in 4:
		d.append(make_card(-1, "wild"))
		d.append(make_card(-1, "wild4"))
	return d

func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t

# 숫자 카드가 나올 때까지 뒤집는다. 특수 카드는 덱 아무 자리에 다시 끼운다.
func _flip_first() -> void:
	while true:
		var c: Dictionary = deck.pop_back()
		if c.kind == "num":
			discard.append(c)
			cur_color = c.color
			return
		deck.insert(rng.randi_range(0, deck.size()), c)

func top() -> Dictionary:
	return discard.back()

func can_play(card: Dictionary) -> bool:
	if card.kind == "wild" or card.kind == "wild4":
		return true
	if card.color == cur_color:
		return true
	var t: Dictionary = top()
	if card.kind == "num":
		return t.kind == "num" and t.num == card.num
	return t.kind == card.kind

func alive_count() -> int:
	var c := 0
	for a in alive:
		if a:
			c += 1
	return c

func _step(from: int, steps: int) -> int:
	var s := from
	for i in steps:
		s = posmod(s + dir, n)
		var guard := 0
		while not alive[s] and guard < n:
			s = posmod(s + dir, n)
			guard += 1
	return s

func _advance(steps: int) -> void:
	turn = _step(turn, steps)
	phase = "pick"
	drawn_idx = -1

func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _gate(seat: int, want: String) -> String:
	if phase == "done":
		return "판이 끝났어요"
	if seat < 0 or seat >= n or not alive[seat]:
		return "자리가 없어요"
	if phase == "hanjang":
		return "한장! 판정 중"
	if seat != turn:
		return "차례가 아니에요"
	if phase != want:
		return "지금은 할 수 없어요"
	return ""

# 한 장 뽑는다. 덱이 비면 더미를 섞어 쓰고, 둘 다 비면 null.
func _draw_one(seat: int):
	if deck.is_empty() and discard.size() > 1:
		var t: Dictionary = discard.pop_back()
		deck = discard
		discard = [t]
		shuffle(deck)
	if deck.is_empty():
		return null
	var c: Dictionary = deck.pop_back()
	hands[seat].append(c)
	return c

func _draw_many(seat: int, count: int) -> int:
	var got := 0
	for i in count:
		if _draw_one(seat) == null:
			break
		got += 1
	return got

func play(seat: int, idx: int, color: int = -1) -> Dictionary:
	var why := _gate(seat, "drawn" if phase == "drawn" else "pick")
	if why != "":
		return _fail(why)
	if idx < 0 or idx >= hands[seat].size():
		return _fail("그 카드가 패에 없어요")
	if phase == "drawn" and idx != drawn_idx:
		return _fail("뽑은 카드만 낼 수 있어요")
	var card: Dictionary = hands[seat][idx]
	if not can_play(card):
		return _fail("낼 수 없는 카드예요")
	if (card.kind == "wild" or card.kind == "wild4") and color != -1 and (color < 0 or color > 3):
		return _fail("색이 아니에요")
	hands[seat].remove_at(idx)
	discard.append(card)
	drawn_idx = -1
	if hands[seat].is_empty():
		_finish(seat)
		return {"ok": true, "reason": "", "finished": true}
	if card.kind == "wild" or card.kind == "wild4":
		pending_wild = card
		phase = "color"
		if color >= 0:
			return choose_color(seat, color)
		return {"ok": true, "reason": "", "need_color": true}
	_apply(seat, card)
	return {"ok": true, "reason": ""}

func choose_color(seat: int, color: int) -> Dictionary:
	var why := _gate(seat, "color")
	if why != "":
		return _fail(why)
	if color < 0 or color > 3:
		return _fail("색이 아니에요")
	cur_color = color
	var card := pending_wild
	pending_wild = {}
	_apply(seat, card)
	return {"ok": true, "reason": ""}

# 낸 카드의 효과를 적용하고 차례를 넘긴다. 1장 남았으면 한장! 판정 창을 연다.
func _apply(seat: int, card: Dictionary) -> void:
	match card.kind:
		"num":
			cur_color = card.color
			_advance(1)
		"skip":
			cur_color = card.color
			_advance(2)
		"rev":
			cur_color = card.color
			if alive_count() == 2:
				_advance(2)
			else:
				dir = -dir
				_advance(1)
		"draw2":
			cur_color = card.color
			_draw_many(_step(turn, 1), 2)
			_advance(2)
		"wild":
			_advance(1)
		"wild4":
			_draw_many(_step(turn, 1), 4)
			_advance(2)
	if hands[seat].size() == 1:
		hj_seat = seat
		phase = "hanjang"

func draw(seat: int) -> Dictionary:
	var why := _gate(seat, "pick")
	if why != "":
		return _fail(why)
	var c = _draw_one(seat)
	if c == null:
		_advance(1)
		return {"ok": true, "reason": "", "drawn": false}
	if can_play(c):
		drawn_idx = hands[seat].size() - 1
		phase = "drawn"
		return {"ok": true, "reason": "", "drawn": true, "playable": true}
	_advance(1)
	return {"ok": true, "reason": "", "drawn": true, "playable": false}

# 뽑은 카드를 내지 않고 가진다(시간이 다 됐을 때도 이쪽).
func keep_drawn(seat: int) -> Dictionary:
	var why := _gate(seat, "drawn")
	if why != "":
		return _fail(why)
	_advance(1)
	return {"ok": true, "reason": ""}

# 한장! 을 외친다. 낸 사람 본인만 된다.
func call_hanjang(seat: int) -> Dictionary:
	if phase != "hanjang" or seat != hj_seat:
		return _fail("외칠 수 없어요")
	_close_window()
	return {"ok": true, "reason": ""}

# 잡았다! — 창이 열려 있을 때 먼저 온 한 사람만 받는다. 잡힌 사람은 2장을 받는다.
func catch_hanjang(by_seat: int) -> Dictionary:
	if phase != "hanjang" or by_seat == hj_seat or by_seat < 0 or by_seat >= n or not alive[by_seat]:
		return _fail("잡을 수 없어요")
	var victim := hj_seat
	_draw_many(victim, 2)
	_close_window()
	return {"ok": true, "reason": "", "victim": victim}

# 창 시간이 다 됐다(아무도 안 눌렀다). 장수는 그대로다.
func close_hanjang() -> Dictionary:
	if phase != "hanjang":
		return _fail("열린 창이 없어요")
	_close_window()
	return {"ok": true, "reason": ""}

func _close_window() -> void:
	hj_seat = -1
	phase = "pick"

# 색 고르기 시간이 다 됐을 때 쓸 색: 패에 가장 많은 색, 같으면 빨강부터.
func auto_color(seat: int) -> int:
	var cnt := [0, 0, 0, 0]
	for c in hands[seat]:
		if c.color >= 0:
			cnt[c.color] += 1
	var best := 0
	for i in range(1, 4):
		if cnt[i] > cnt[best]:
			best = i
	return best

func _finish(win_seat: int) -> void:
	winner = win_seat
	phase = "done"
	hj_seat = -1
	pending_wild = {}

# 자리가 나갔다. 패는 덱에 넣고 섞는다. 차례였으면 넘기고, 1명 남으면 판이 끝난다.
## 나갔던 자리가 같은 닉네임으로 돌아온다. 패는 처음 장수만큼 새로 받고, 판이 끝났으면 못 돌아온다.
func rejoin(seat: int) -> Dictionary:
	if seat < 0 or seat >= n or alive[seat] or phase == "done":
		return _fail("돌아올 수 없는 자리예요")
	alive[seat] = true
	for i in HAND_SIZE:
		if deck.is_empty():
			break
		hands[seat].append(deck.pop_back())
	return {"ok": true, "reason": ""}

func leave(seat: int) -> Dictionary:
	if seat < 0 or seat >= n or not alive[seat]:
		return _fail("이미 없는 자리예요")
	if turn == seat and phase == "color":
		cur_color = auto_color(seat) # 색 고르던 사람이 나가면 시간 초과와 같은 색. 와일드+4 벌칙은 적용하지 않는다
		pending_wild = {}
	alive[seat] = false
	deck.append_array(hands[seat])
	hands[seat] = []
	shuffle(deck)
	if phase == "done":
		return {"ok": true, "reason": ""}
	if alive_count() <= 1:
		for i in n:
			if alive[i]:
				_finish(i)
		return {"ok": true, "reason": "", "finished": true}
	if hj_seat == seat:
		hj_seat = -1
		if phase == "hanjang":
			phase = "pick"
	if turn == seat:
		turn = _step(seat, 1)
		phase = "hanjang" if hj_seat >= 0 else "pick"
		drawn_idx = -1
	return {"ok": true, "reason": ""}

# 등수: 다 턴 사람 1등, 나머지는 남은 장수 적은 순(같으면 같은 등수). 나간 자리는 0.
func ranking() -> Array:
	var ranks: Array = []
	for i in n:
		ranks.append(0)
	if winner < 0:
		return ranks
	ranks[winner] = 1
	var others: Array = []
	for i in n:
		if i != winner and alive[i]:
			others.append(i)
	for i in others:
		var better := 0
		for j in others:
			if hands[j].size() < hands[i].size():
				better += 1
		ranks[i] = 2 + better
	return ranks

func snapshot_for(seat: int) -> Dictionary:
	var counts: Array = []
	for i in n:
		counts.append(hands[i].size())
	var mine: Array = []
	if seat >= 0 and seat < n:
		mine = hands[seat].duplicate(true)
	var drawn_id := -1
	if phase == "drawn" and seat == turn and drawn_idx >= 0 and drawn_idx < hands[seat].size():
		drawn_id = hands[seat][drawn_idx].id
	return {
		"seat": seat, "n": n, "top": top().duplicate(), "color": cur_color,
		"counts": counts, "alive": alive.duplicate(), "turn": turn, "dir": dir,
		"phase": phase, "hanjang_seat": hj_seat, "hand": mine, "drawn_id": drawn_id,
		"deck_count": deck.size(), "winner": winner, "ranks": ranking(),
	}
