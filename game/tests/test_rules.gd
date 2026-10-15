extends SceneTree
## 규칙 엔진 헤드리스 시험. 실패가 하나라도 있으면 종료 코드 1.
## engine/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/test_rules.gd

const Rules := preload("res://rules/rules.gd")

var fails := 0

func check(cond: bool, name: String) -> void:
	if cond:
		print("ok   ", name)
	else:
		fails += 1
		print("FAIL ", name)

func fresh(count: int, seed_value: int = 1) -> Rules:
	var r := Rules.new()
	r.setup(count, seed_value)
	return r

# 판을 시험용으로 고정한다: 더미 맨 위, 색, 각자 패, 덱.
func stage(r: Rules, top_card: Dictionary, color: int, hand_list: Array, deck_cards: Array = []) -> void:
	r.discard = [top_card]
	r.cur_color = color
	for i in r.n:
		r.hands[i] = hand_list[i] if i < hand_list.size() else [r.make_card(0, "num", 1), r.make_card(0, "num", 2), r.make_card(0, "num", 3)]
	r.deck = deck_cards
	r.turn = 0
	r.dir = 1
	r.phase = "pick"
	r.hj_seat = -1
	r.winner = -1

func filler(r: Rules, count: int) -> Array:
	var a: Array = []
	for i in count:
		a.append(r.make_card(1, "num", 9))
	return a

func _init() -> void:
	t1_deal()
	t2_playable()
	t3_effects()
	t4_reshuffle()
	t5_hanjang()
	t6_ranking()
	edge_cases()
	snapshot_hides_hands()
	print("실패 ", fails, "개")
	quit(1 if fails > 0 else 0)

func t1_deal() -> void:
	var bad := 0
	for count in [2, 3, 4]:
		for s in 100:
			var r := fresh(count, s)
			var total := r.deck.size() + r.discard.size()
			var ok := true
			for i in count:
				ok = ok and r.hands[i].size() == 7
				total += r.hands[i].size()
			ok = ok and total == 108 and r.top().kind == "num" and r.discard.size() == 1
			ok = ok and r.cur_color == r.top().color
			if not ok:
				bad += 1
	check(bad == 0, "T1 2·3·4명 고정 시드 100개씩 7장·108장·첫 카드 숫자 (실패 %d)" % bad)
	var r2 := fresh(4, 5)
	var r3 := fresh(4, 5)
	check(r2.top().id == r3.top().id and r2.hands[0][0].id == r3.hands[0][0].id, "T1 같은 시드는 같은 판")
	var kinds := {}
	for c in r2.build_deck():
		var k := "%d%s%d" % [c.color, c.kind, c.num]
		kinds[k] = kinds.get(k, 0) + 1
	check(kinds["0num0"] == 1 and kinds["2num5"] == 2 and kinds["3skip-1"] == 2 and kinds["-1wild4-1"] == 4 and kinds["-1wild-1"] == 4, "T1 덱 구성 표준 108장")

func t2_playable() -> void:
	var r := fresh(2)
	var red7 := r.make_card(0, "num", 7)
	stage(r, red7, 0, [])
	check(r.can_play(r.make_card(0, "num", 3)), "T2 같은 색 숫자")
	check(r.can_play(r.make_card(2, "num", 7)), "T2 같은 숫자 다른 색")
	check(not r.can_play(r.make_card(2, "num", 3)), "T2 색·숫자 다르면 못 냄")
	check(r.can_play(r.make_card(-1, "wild")) and r.can_play(r.make_card(-1, "wild4")), "T2 와일드는 언제나")
	check(r.can_play(r.make_card(0, "skip")), "T2 같은 색 특수")
	check(not r.can_play(r.make_card(1, "skip")), "T2 다른 색 특수 못 냄")
	stage(r, r.make_card(1, "skip"), 1, [])
	check(r.can_play(r.make_card(3, "skip")), "T2 같은 기호 특수 카드")
	check(not r.can_play(r.make_card(3, "rev")), "T2 다른 기호 특수 못 냄")
	stage(r, r.make_card(-1, "wild"), 3, [])
	check(r.can_play(r.make_card(3, "num", 4)), "T2 정한 색 파랑이면 파랑 가능")
	check(not r.can_play(r.make_card(0, "num", 4)), "T2 정한 색 파랑이면 빨강 불가")

func t3_effects() -> void:
	var r := fresh(4)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(0, "skip"), r.make_card(1, "num", 1)]])
	r.play(0, 0)
	check(r.turn == 2, "T3 스킵 → 3번 차례")
	r = fresh(4)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(0, "rev"), r.make_card(1, "num", 1)]])
	r.play(0, 0)
	check(r.turn == 3 and r.dir == -1, "T3 리버스 → 4번 차례, 방향 바뀜")
	r = fresh(4)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(0, "draw2"), r.make_card(1, "num", 1)]], filler(r, 10))
	r.play(0, 0)
	check(r.turn == 2 and r.hands[1].size() == 5, "T3 +2 → 2번 2장 받고 3번 차례")
	r = fresh(4)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(-1, "wild4"), r.make_card(1, "num", 1)]], filler(r, 10))
	var res := r.play(0, 0)
	check(res.need_color and r.phase == "color", "T3 와일드+4는 색 고르는 중")
	r.choose_color(0, 2)
	check(r.turn == 2 and r.hands[1].size() == 7 and r.cur_color == 2, "T3 +4 → 2번 4장 받고 3번 차례, 색 초록")
	r = fresh(2)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(0, "rev"), r.make_card(1, "num", 1)]])
	r.play(0, 0)
	check(r.turn == 0, "T3 2명 리버스는 낸 사람이 한 번 더")
	r = fresh(2)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(-1, "wild"), r.make_card(1, "num", 1)]])
	r.play(0, 0, 1)
	check(r.cur_color == 1 and r.turn == 1, "T3 와일드 색 정하기 → 다음 사람이 맞출 색")

func t4_reshuffle() -> void:
	var r := fresh(2)
	var pile: Array = filler(r, 9)
	pile.append(r.make_card(0, "num", 5))
	stage(r, pile.back(), 0, [[r.make_card(2, "num", 1)], [r.make_card(2, "num", 2)]], [])
	r.discard = pile
	var top_id: int = pile.back().id
	r.draw(0)
	check(r.discard.size() == 1 and r.discard[0].id == top_id, "T4 더미 맨 위 한 장만 남음")
	check(r.deck.size() == 8 and r.hands[0].size() == 2, "T4 뽑은 뒤 덱 8장")
	r = fresh(2)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(2, "num", 1)], [r.make_card(2, "num", 2)]], [])
	var res := r.draw(0)
	check(res.ok and res.drawn == false and r.turn == 1 and r.hands[0].size() == 1, "T4 덱·더미 둘 다 비면 뽑지 않고 차례 넘김")
	r = fresh(2)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(2, "num", 1)], [r.make_card(2, "num", 2)]], [r.make_card(0, "num", 9)])
	res = r.draw(0)
	check(r.phase == "drawn", "경계 뽑은 카드가 낼 수 있으면 뽑은 카드 고르는 중")
	check(r.play(0, 0).ok == false, "경계 뽑은 카드 말고 다른 카드는 못 냄")
	check(r.keep_drawn(0).ok and r.turn == 1 and r.hands[0].size() == 2, "경계 뽑은 카드 가지기 → 차례 넘김")

func make_hanjang() -> Rules:
	var r := fresh(3)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(0, "num", 1), r.make_card(0, "num", 2)]], filler(r, 10))
	r.play(0, 0)
	return r

func t5_hanjang() -> void:
	var r := make_hanjang()
	check(r.phase == "hanjang" and r.hj_seat == 0 and r.turn == 1, "T5 2장에서 1장 내면 한장! 판정 중")
	check(r.play(1, 0).ok == false, "T5 판정 중에는 다음 사람이 못 냄")
	r.call_hanjang(0)
	check(r.hands[0].size() == 1 and r.phase == "pick", "T5 외치면 1장 그대로")
	r = make_hanjang()
	var c1 := r.catch_hanjang(2)
	var c2 := r.catch_hanjang(1)
	check(c1.ok and r.hands[0].size() == 3 and not c2.ok, "T5 잡히면 3장, 잡았다! 둘째 요청은 무시")
	check(r.phase == "pick" and r.turn == 1, "T5 잡힌 뒤 다음 사람 차례")
	r = make_hanjang()
	check(not r.catch_hanjang(0).ok, "T5 본인은 자기를 못 잡음")
	r.close_hanjang()
	check(r.hands[0].size() == 1 and r.phase == "pick", "T5 아무도 안 누르면 1장 그대로")
	r = make_hanjang()
	r.call_hanjang(0)
	check(not r.catch_hanjang(1).ok, "T5 외친 뒤에는 못 잡음")

func t6_ranking() -> void:
	var r := fresh(4)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(0, "num", 1)], filler(r, 3), filler(r, 5), filler(r, 3)])
	r.play(0, 0)
	var rk := r.ranking()
	check(r.phase == "done" and r.winner == 0, "T6 패를 다 털면 판 끝")
	check(rk == [1, 2, 4, 2], "T6 3·5·3장 → 1등, 2등, 4등, 2등 (%s)" % str(rk))

func edge_cases() -> void:
	var r := fresh(4)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(0, "num", 1), r.make_card(0, "num", 2)]])
	check(not r.play(1, 0).ok, "경계 차례 아닌 사람 요청 무시")
	check(not r.play(0, 5).ok, "경계 패에 없는 카드 요청 무시")
	r.hands[0] = [r.make_card(2, "num", 1), r.make_card(2, "num", 2)]
	check(not r.play(0, 0).ok and r.turn == 0, "경계 낼 수 없는 카드 요청 무시")
	r = fresh(4)
	r.hands[0] = [r.make_card(0, "num", 1), r.make_card(1, "num", 1), r.make_card(1, "num", 2)]
	check(r.auto_color(0) == 1, "경계 시간 초과 색은 패에 가장 많은 색")
	r.hands[0] = [r.make_card(2, "num", 1), r.make_card(1, "num", 1)]
	check(r.auto_color(0) == 1, "경계 같으면 앞 색부터(노랑·초록 동수 → 노랑)")
	r.hands[0] = [r.make_card(3, "num", 1), r.make_card(0, "num", 1)]
	check(r.auto_color(0) == 0, "경계 같으면 빨강부터")
	r.hands[0] = [r.make_card(-1, "wild")]
	check(r.auto_color(0) == 0, "경계 색 카드가 없으면 빨강")
	r = fresh(4)
	stage(r, r.make_card(0, "num", 5), 0, [])
	var before := r.deck.size() + 3
	r.leave(0)
	check(r.deck.size() == before and r.turn == 1 and not r.alive[0], "경계 나간 사람 패는 덱으로, 차례였으면 다음 사람")
	r.leave(2)
	check(r.phase == "pick" and r.alive_count() == 2, "경계 둘이 남아도 계속")
	r.leave(3)
	check(r.phase == "done" and r.winner == 1 and r.ranking() == [0, 1, 0, 0], "경계 1명 남으면 끝, 나간 사람은 등수 없음")
	r = fresh(4)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(0, "num", 1), r.make_card(0, "num", 2)]])
	r.leave(1)
	r.play(0, 0)
	check(r.turn == 2, "경계 나간 자리는 건너뜀")
	r = fresh(3)
	stage(r, r.make_card(0, "num", 5), 0, [[r.make_card(-1, "wild"), r.make_card(1, "num", 1)]])
	r.play(0, 0)
	r.leave(0)
	check(r.turn == 1 and r.phase == "pick", "경계 색 고르는 중에 나가면 다음 사람 차례")

func collect_ids(v, out: Array) -> void:
	if v is Dictionary:
		if v.has("kind") and v.has("id"):
			out.append(v.id)
		for k in v:
			collect_ids(v[k], out)
	elif v is Array:
		for x in v:
			collect_ids(x, out)

func snapshot_hides_hands() -> void:
	var leaks := 0
	for s in 50:
		var r := fresh(4, s)
		for seat in 4:
			var snap := r.snapshot_for(seat)
			var ids: Array = []
			collect_ids(snap, ids)
			for other in 4:
				if other == seat:
					continue
				for c in r.hands[other]:
					if ids.has(c.id):
						leaks += 1
			if snap.hand.size() != 7 or snap.counts[(seat + 1) % 4] != 7:
				leaks += 1
	check(leaks == 0, "snapshot_for 에 다른 자리의 패 카드 값이 없음 (누출 %d)" % leaks)
	var r2 := fresh(2, 3)
	var snap2 := r2.snapshot_for(1)
	check(snap2.has("top") and snap2.has("color") and snap2.has("counts") and snap2.has("turn") and snap2.has("dir") and snap2.has("phase"), "snapshot_for 필수 칸")
