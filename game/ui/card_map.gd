extends RefCounted
## 규칙 엔진 카드(색 정수, kind)를 CardView 값(색 문자열, 값 문자열)으로 바꾸는 유일한 자리.

const COLORS := ["red", "yellow", "green", "blue"]


static func view_color(card: Dictionary) -> String:
	return "wild" if card.color < 0 else COLORS[card.color]


static func view_value(card: Dictionary) -> String:
	match card.kind:
		"num":
			return str(card.num)
		"rev":
			return "reverse"
		"draw2":
			return "plus2"
	return card.kind  # skip, wild, wild4
