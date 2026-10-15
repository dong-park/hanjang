extends RefCounted
## 판 상태가 바뀐 것을 보고 어떤 연출을 할지 고른다. 화면을 모르는 순수 함수라 헤드리스로 시험한다.
## 입력: 앞 스냅샷과 새 스냅샷(rules.gd snapshot_for 형태). 출력: 이벤트 사전의 배열.
##   {"type": "attack", "by": 낸 자리, "victim": 받는 자리, "amount": 장수, "kind": "draw2"|"wild4"}
##   {"type": "skip", "by": 낸 자리, "seat": 건너뛴 자리}
##   {"type": "reverse", "by": 낸 자리, "clockwise": 새 방향이 시계인가}
## 한장! 결과(외침·잡았다!)는 스냅샷만으로 누가 했는지 알 수 없어 여기서 고르지 않는다. table.show_event 로 받는다.


static func next_alive(s: Dictionary, from: int, dir: int) -> int:
	var i := from
	for _k in s.n:
		i = posmod(i + dir, s.n)
		if s.alive[i] and i != from:
			return i
	return -1


static func derive(prev: Dictionary, s: Dictionary) -> Array:
	var out: Array = []
	if prev.is_empty() or s.is_empty() or prev.n != s.n:
		return out
	var player: int = prev.turn
	var top_changed: bool = prev.top.id != s.top.id
	var wild_chosen: bool = prev.phase == "color" and s.phase != "color"
	if not (top_changed or wild_chosen):
		return out
	var kind: String = s.top.kind
	if kind == "draw2" or kind == "wild4":
		# 와일드+4는 색을 고른 뒤에 효과가 적용된다. 받는 사람은 장수가 늘어난 자리다.
		var victim := -1
		var best := 0
		for i in s.n:
			if i == player:
				continue
			var inc: int = s.counts[i] - prev.counts[i]
			if inc > best:
				best = inc
				victim = i
		if victim >= 0:
			out.append({"type": "attack", "by": player, "victim": victim, "amount": best, "kind": kind})
	elif top_changed and kind == "skip":
		var sk := next_alive(prev, player, prev.dir)
		if sk >= 0:
			out.append({"type": "skip", "by": player, "seat": sk})
	elif top_changed and kind == "rev":
		if s.dir != prev.dir:
			out.append({"type": "reverse", "by": player, "clockwise": s.dir > 0})
		else:
			# 2명일 때 리버스는 스킵과 같다.
			var sk2 := next_alive(prev, player, prev.dir)
			if sk2 >= 0:
				out.append({"type": "skip", "by": player, "seat": sk2})
	return out
