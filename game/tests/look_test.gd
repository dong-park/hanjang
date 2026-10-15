extends SceneTree
## 룩 부품 시험. 실행:
## engine/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/look_test.gd

const CardViewScript := preload("res://ui/card_view.gd")
const AvatarViewScript := preload("res://ui/avatar_view.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	var values := ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "skip", "reverse", "plus2"]
	for c in ["red", "yellow", "green", "blue"]:
		for v in values:
			var p: String = CardViewScript.texture_path(c, v)
			check(ResourceLoader.exists(p), "card texture " + p)
	for v in ["wild", "wild4"]:
		check(ResourceLoader.exists(CardViewScript.texture_path("wild", v)), "card texture " + v)
	check(ResourceLoader.exists("res://assets/cards/back.png"), "back texture")

	var cv: Control = CardViewScript.new()
	cv.show_card("blue", "plus2")
	check(cv.current_texture_path().ends_with("blue_plus2.png"), "path for blue plus2")
	cv.show_back()
	check(cv.current_texture_path().ends_with("back.png"), "back path")
	cv.set_card_size(CardViewScript.CardSize.SMALL)
	check(cv.card_pixel_size() == Vector2(40, 56), "small size")
	cv.set_card_size(CardViewScript.CardSize.LARGE)
	check(cv.card_pixel_size() == Vector2(120, 168), "large size")
	cv.set_lift(CardViewScript.Lift.RAISED)
	check(cv.get_child(0).position.y < 0, "raised moves up")
	cv.set_dimmed(true)
	check(cv.get_child(0).modulate.r < 1.0, "dimmed darkens")
	cv.free()

	var av: Control = AvatarViewScript.new()
	av.setup(5, "하늘", AvatarViewScript.State.TURN, true)
	check(av.face == 1, "face index wraps")
	check(av._crown.visible, "host crown visible")
	av.free()

	var theme: Theme = load("res://ui/theme.tres")
	check(theme != null and theme.default_font != null, "theme loads with font")
	check(theme != null and theme.has_stylebox("normal", "Button"), "theme has button style")
	for i in 4:
		check(ResourceLoader.exists("res://assets/avatars/face_%d.png" % i), "avatar %d" % i)

	print("LOOK_TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails else 0)

