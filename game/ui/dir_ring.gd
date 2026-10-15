extends Control
## 방향 고리: 이어진 점선 타원과 화살표 4개. clockwise 가 거짓이면 반대로 돈다.

var clockwise := true:
	set(v):
		clockwise = v
		queue_redraw()

const CENTER := Vector2(576, 298)
const RADII := Vector2(132, 104)
const COLOR := Color("4a64d8")
const DASHES := 36


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _pt(a: float) -> Vector2:
	return CENTER + Vector2(cos(a) * RADII.x, sin(a) * RADII.y)


func _draw() -> void:
	var step := TAU / DASHES
	for i in DASHES:
		var a0 := i * step
		var pts := PackedVector2Array()
		for k in 5:
			pts.append(_pt(a0 + step * 0.55 * k / 4.0))
		draw_polyline(pts, COLOR, 5.0)
	# 화살표 4개: 위·오른쪽·아래·왼쪽. 시계 방향이면 위는 오른쪽, 오른쪽은 아래를 가리킨다.
	for q in 4:
		var a := -PI / 2.0 + q * PI / 2.0 + step * 0.275
		var p := _pt(a)
		var tan := Vector2(-sin(a) * RADII.x, cos(a) * RADII.y).normalized()
		if not clockwise:
			tan = -tan
		var nrm := Vector2(-tan.y, tan.x)
		draw_colored_polygon(PackedVector2Array([p + tan * 14.0, p - tan * 8.0 + nrm * 11.0, p - tan * 8.0 - nrm * 11.0]), COLOR)
