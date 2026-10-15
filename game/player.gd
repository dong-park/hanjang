extends Node2D
# 플레이어 한 명. 자기 컴퓨터의 플레이어만 키보드로 움직이고, 위치를 다른 사람에게 보낸다.

const SPEED := 320.0
const RADIUS := 22.0
const ARENA := Rect2(30, 30, 1092, 588)

var peer_id := 1
var color := Color.WHITE
var is_it := false

func _enter_tree() -> void:
	set_multiplayer_authority(peer_id)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		dir = Vector2(
			int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
			int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
		).normalized()
	var speed := SPEED * (1.15 if is_it else 1.0)  # 술래가 조금 빠르다
	position = (position + dir * speed * delta).clamp(ARENA.position, ARENA.end)
	_sync_position.rpc(position)

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_position(pos: Vector2) -> void:
	position = pos

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if is_it:
		draw_circle(Vector2.ZERO, RADIUS + 7, Color(1, 0.15, 0.15))
	draw_circle(Vector2.ZERO, RADIUS, color)
	var label := "나" if is_multiplayer_authority() else "P%d" % (get_index() + 1)
	if is_it:
		label += " (술래)"
	draw_string(ThemeDB.fallback_font, Vector2(-60, -RADIUS - 12), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 16)
