extends Node2D
# 방 만들기/접속 화면과 게임 진행(술래 넘기기)을 맡는다. 판정은 방장(서버)이 한다.

const PORT := 7777
const PlayerScript := preload("res://player.gd")
const COLORS := [Color("4fc3f7"), Color("aed581"), Color("ffd54f"), Color("ba68c8"), Color("ff8a65"), Color("4db6ac")]

var players: Node2D
var spawner: MultiplayerSpawner
var menu: VBoxContainer
var ip_edit: LineEdit
var status: Label
var it_id := 0
var tag_cooldown := 0.0
var color_index := 0
var reported := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("263238"))
	players = Node2D.new()
	players.name = "Players"
	add_child(players)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_function = _make_player
	_build_ui()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): _set_status("접속 성공! 방향키나 WASD로 움직이세요."))
	multiplayer.connection_failed.connect(func(): _set_status("접속 실패. IP를 확인하세요."); menu.show())
	multiplayer.server_disconnected.connect(func(): _set_status("방장이 나갔어요."); menu.show())

	# 명령줄 실행용: -- --host 또는 -- --join=IP
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			host_game()
		elif arg.begins_with("--join="):
			ip_edit.text = arg.trim_prefix("--join=")
			join_game()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(16, 8)
	layer.add_child(status)
	menu = VBoxContainer.new()
	menu.position = Vector2(426, 220)
	menu.custom_minimum_size = Vector2(300, 0)
	layer.add_child(menu)
	var title := Label.new()
	title.text = "멀티 술래잡기"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	var host_btn := Button.new()
	host_btn.text = "방 만들기"
	host_btn.pressed.connect(host_game)
	menu.add_child(host_btn)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "방장 IP"
	menu.add_child(ip_edit)
	var join_btn := Button.new()
	join_btn.text = "접속하기"
	join_btn.pressed.connect(join_game)
	menu.add_child(join_btn)
	_set_status("방을 만들거나 방장 IP로 접속하세요.")

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 8) != OK:
		_set_status("방 만들기 실패 (포트 %d 사용 중?)" % PORT)
		return
	multiplayer.multiplayer_peer = peer
	menu.hide()
	_spawn_for(1)
	_set_status("방 열림. 같은 와이파이 친구는 이 IP로 접속: %s" % ", ".join(_lan_ips()))
	print("HOST_READY")

func join_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip_edit.text.strip_edges(), PORT) != OK:
		_set_status("접속 시작 실패")
		return
	multiplayer.multiplayer_peer = peer
	menu.hide()
	_set_status("접속 중...")

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_spawn_for(id)
		_set_it.rpc_id(id, it_id)
		print("PEER_JOINED ", id)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var node := players.get_node_or_null(str(id))
	if node:
		node.queue_free()
	if id == it_id:
		_set_it.rpc(1)

func _spawn_for(id: int) -> void:
	var pos := Vector2(randf_range(100, 1050), randf_range(100, 550))
	spawner.spawn({"id": id, "color": COLORS[color_index % COLORS.size()], "pos": pos})
	color_index += 1
	if it_id == 0:
		_set_it.rpc(id)

func _make_player(data: Dictionary) -> Node:
	var p := PlayerScript.new()
	p.name = str(data.id)
	p.peer_id = data.id
	p.color = data.color
	p.position = data.pos
	p.is_it = data.id == it_id
	return p

@rpc("authority", "call_local", "reliable")
func _set_it(id: int) -> void:
	it_id = id
	for p in players.get_children():
		p.is_it = p.peer_id == id

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	tag_cooldown -= delta
	var it_node := players.get_node_or_null(str(it_id))
	if it_node == null or tag_cooldown > 0:
		return
	for p in players.get_children():
		if p != it_node and p.position.distance_to(it_node.position) < PlayerScript.RADIUS * 2:
			tag_cooldown = 1.0  # 바로 되돌려 잡기 방지
			_set_it.rpc(p.peer_id)
			print("TAGGED ", p.peer_id)
			break

func _process(_delta: float) -> void:
	if not reported and multiplayer.multiplayer_peer and not multiplayer.is_server() and players.get_child_count() >= 2:
		reported = true
		print("CLIENT_SEES_PLAYERS ", players.get_child_count(), " it=", it_id)

func _set_status(t: String) -> void:
	status.text = t

func _lan_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			out.append(a)
	return out
