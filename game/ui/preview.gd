extends Control
## 룩 부품 미리보기. 카드 전 종류, 아바타, 버튼, 입력칸, 고리, 시간 바를 한 장에 늘어놓는다.

const BG_TILE := preload("res://assets/ui/bg_tile.png")


func _ready() -> void:
	theme = load("res://ui/theme.tres")
	var bg := TextureRect.new()
	bg.texture = BG_TILE
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 1줄: 빨강 13종
	var x := 16.0
	for v in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "skip", "reverse", "plus2"]:
		_card("red", v, Vector2(x, 24))
		x += 88.0
	# 2줄: 다른 색, 검정, 뒷면, 상태
	x = 16.0
	for cv in [["yellow", "8"], ["green", "3"], ["blue", "5"], ["yellow", "skip"], ["green", "reverse"],
			["blue", "plus2"], ["wild", "wild"], ["wild", "wild4"]]:
		_card(cv[0], cv[1], Vector2(x, 160))
		x += 88.0
	var back := _card("red", "0", Vector2(x, 160)); back.show_back(); x += 88.0
	_card("red", "7", Vector2(x, 160)).set_lift(CardView.Lift.RAISED); x += 88.0
	_card("blue", "5", Vector2(x, 160)).set_dimmed(true); x += 88.0
	_card("green", "9", Vector2(x, 160)).set_lift(CardView.Lift.PICKED); x += 100.0
	_card("yellow", "2", Vector2(x, 160)).set_card_size(CardView.CardSize.SMALL)
	# 3줄: 아바타
	var ax := 24.0
	for i in 4:
		var a := AvatarView.new()
		a.position = Vector2(ax, 300)
		add_child(a)
		a.setup(i, ["하늘", "민트", "체리", "나"][i], AvatarView.State.NORMAL, i == 3)
		ax += 120.0
	var turn := AvatarView.new(); turn.position = Vector2(ax, 300); add_child(turn)
	turn.setup(0, "차례", AvatarView.State.TURN); ax += 120.0
	var gray := AvatarView.new(); gray.position = Vector2(ax, 300); add_child(gray)
	gray.setup(1, "나감", AvatarView.State.GRAY)
	# 4줄: 큰 카드, 고리, 패널, 버튼, 입력칸, 시간 바
	var big := _card("red", "7", Vector2(24, 420)); big.set_card_size(CardView.CardSize.LARGE)
	var ring := TextureRect.new()
	ring.texture = load("res://assets/ui/ring.png")
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.position = Vector2(180, 420); ring.size = Vector2(170, 170)
	add_child(ring)
	var panel := PanelContainer.new()
	panel.position = Vector2(380, 420); panel.size = Vector2(300, 170)
	var pl := Label.new(); pl.text = "패널 안의 글자"
	panel.add_child(pl)
	add_child(panel)
	var btn := Button.new(); btn.text = "뽑기"; btn.position = Vector2(720, 420); btn.size = Vector2(200, 64)
	add_child(btn)
	var btn2 := Button.new(); btn2.text = "시작"; btn2.disabled = true; btn2.position = Vector2(940, 420); btn2.size = Vector2(190, 64)
	add_child(btn2)
	var le := LineEdit.new(); le.text = "닉네임"; le.position = Vector2(720, 500); le.size = Vector2(410, 56)
	add_child(le)
	var bar := ProgressBar.new(); bar.value = 65; bar.show_percentage = false
	bar.position = Vector2(720, 576); bar.size = Vector2(410, 24)
	add_child(bar)


func _card(c: String, v: String, pos: Vector2) -> CardView:
	var cv := CardView.new()
	cv.position = pos
	add_child(cv)
	cv.show_card(c, v)
	return cv

