extends Node
## 방 연결과 자리 관리 (autoload "Room"). 방장(서버)이 자리를 정하고 모두에게 보낸다.
##
## n4(세션)가 받을 시그널:
##   seats_changed(seats: Array)   자리 목록이 바뀔 때. 각 원소 {"peer": int, "name": String, "face": int}.
##                                  0번 자리는 늘 방장(peer 1). 들어온 순서대로 채운다.
##   game_started(seats: Array)    방장이 시작을 눌러 모든 접속자에게 나갈 때 (방장 자신 포함).
##   peer_left(peer: int)          판 중에 접속자가 나갔을 때 (방장만 받는다). 판 중에는 seats에서 지우지 않는다.
##   left_to_title(reason: String) 방장이 나갔거나 접속이 끊겨 첫 화면으로 돌아갈 때.
##   joined()                      참가·방 만들기에 성공해 대기실로 갈 때.
##   join_failed(reason: String)   들어갈 수 없을 때. 참가 화면에 남는다.
## 상태: state == State.LOBBY | State.PLAYING. 판이 끝나 대기실로 돌아올 때는 back_to_lobby()를 부른다.

signal seats_changed(seats: Array)
signal game_started(seats: Array)
signal peer_left(peer: int)
signal left_to_title(reason: String)
signal joined()
signal lobby_returned()
signal join_failed(reason: String)

enum State { NONE, LOBBY, PLAYING }

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
const MIN_PLAYERS := 2
const MAX_NAME := 8
const RECENT_PATH := "user://recent_rooms.json"
const RECENT_MAX := 5

var port := DEFAULT_PORT
var state: State = State.NONE
var seats: Array = []
var my_name := ""
var my_face := 0
var addr := ""          ## 대기실에 보여 줄 방 주소
var _joining := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(func(): _go_title("방장이 나갔어요"))


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func valid_name(n: String) -> bool:
	var t := n.strip_edges()
	return t.length() >= 1 and t.length() <= MAX_NAME


func host_room(p_name: String, p_face: int) -> bool:
	if not valid_name(p_name):
		return false
	my_name = p_name.strip_edges()
	my_face = p_face
	var peer := WebSocketMultiplayerPeer.new()
	# 웹소켓 서버(D1=A). 다섯째 사람에게 이유를 알려 주려고 접속은 받고 자리에서 거절한다.
	if peer.create_server(port) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	state = State.LOBBY
	seats = [{"peer": 1, "name": my_name, "face": my_face}]
	var ips := lan_ips()
	addr = ips[0] if ips.size() > 0 else "127.0.0.1"
	print("HOST_READY ", addr)
	seats_changed.emit(seats)
	joined.emit()
	return true


func join_room(p_name: String, p_face: int, p_addr: String) -> bool:
	if not valid_name(p_name) or p_addr.strip_edges() == "" or _joining:
		return false
	my_name = p_name.strip_edges()
	my_face = p_face
	addr = p_addr.strip_edges()
	var peer := WebSocketMultiplayerPeer.new()
	if peer.create_client(ws_url(addr, port)) != OK:
		join_failed.emit("접속을 시작하지 못했어요")
		return false
	multiplayer.multiplayer_peer = peer
	_joining = true
	return true


func ws_url(p_addr: String, p_port: int) -> String:
	## 방 주소 규칙: 입력은 "192.168.0.5"(포트 7777 기본) 또는 "192.168.0.5:7778". ws:// 로 붙는다.
	var a := p_addr.strip_edges().trim_prefix("ws://")
	if a.contains(":"):
		return "ws://" + a
	return "ws://%s:%d" % [a, p_port]


func leave() -> void:
	## 자리를 비우고 연결을 닫는다. 방장이 부르면 접속자는 모두 첫 화면으로 간다.
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_reset()


func start_game() -> bool:
	## 방장만, 2명 이상일 때만 된다.
	if not is_host() or state != State.LOBBY or seats.size() < MIN_PLAYERS:
		print("START_BLOCKED seats=", seats.size())
		return false
	state = State.PLAYING
	print("START_OK seats=", seats.size())
	_to_seated(_begin, [seats])
	return true


func back_to_lobby() -> void:
	if is_host():
		state = State.LOBBY
		for i in range(seats.size() - 1, -1, -1):
			if seats[i].get("gone", false):
				seats.remove_at(i)
		_to_seated(_to_lobby, [seats])


## 다시 하기: 같은 사람끼리 바로 다음 판. 나간 자리는 비우고, 둘 미만이면 대기실로 간다.
func replay() -> void:
	if not is_host() or state != State.PLAYING:
		return
	for i in range(seats.size() - 1, -1, -1):
		if seats[i].get("gone", false):
			seats.remove_at(i)
	if seats.size() < MIN_PLAYERS:
		back_to_lobby()
		return
	print("REPLAY seats=", seats.size())
	_to_seated(_begin, [seats])


func room_name() -> String:
	return "%s의 방" % seats[0].name if seats.size() > 0 else ""


func lan_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			out.append(a)
	return out


func recent_rooms() -> Array:
	if not FileAccess.file_exists(RECENT_PATH):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(RECENT_PATH))
	return data if data is Array else []


func _remember(p_name: String, p_addr: String) -> void:
	var list := recent_rooms().filter(func(r): return r.get("addr", "") != p_addr)
	list.push_front({"name": p_name, "addr": p_addr})
	if list.size() > RECENT_MAX:
		list.resize(RECENT_MAX)
	var f := FileAccess.open(RECENT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(list))


func _reset() -> void:
	state = State.NONE
	seats = []
	_joining = false


func _go_title(reason: String) -> void:
	print("LEFT_TO_TITLE ", reason)
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_reset()
	left_to_title.emit(reason)


func _on_connected() -> void:
	_hello.rpc_id(1, my_name, my_face)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_joining = false
	print("JOIN_FAILED 접속하지 못했어요")
	join_failed.emit("접속하지 못했어요. 주소를 확인하세요")


func _on_peer_connected(id: int) -> void:
	# 웹소켓 서버는 접속 수 상한 인자가 없다. ENet 때와 같은 상한(MAX_PLAYERS + 3)을 넘는 접속은 바로 끊는다.
	if is_host() and multiplayer.get_peers().size() > MAX_PLAYERS + 3:
		multiplayer.multiplayer_peer.disconnect_peer(id, true)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	for i in seats.size():
		if seats[i].peer == id:
			if state == State.PLAYING:
				seats[i]["gone"] = true
				print("PEER_LEFT_IN_GAME ", id)
				peer_left.emit(id)
			else:
				seats.remove_at(i)
				print("SEAT_FREED ", id, " seats=", seats.size())
				_to_seated(_sync_seats, [seats])
			return


func _to_seated(fn: Callable, args: Array) -> void:
	## 자리에 앉은 접속자에게만 보낸다 (방장 본인은 로컬 호출).
	var me := multiplayer.get_unique_id()
	for s in seats.duplicate():
		if s.peer == me:
			fn.callv(args)
		else:
			fn.rpc_id(s.peer, args[0])


@rpc("any_peer", "call_remote", "reliable")
func _hello(p_name: String, p_face: int) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	for s in seats:
		if s.peer == id:
			return
	var reason := ""
	if state == State.PLAYING:
		reason = "지금 게임 중이에요"
	elif seats.size() >= MAX_PLAYERS:
		reason = "방이 꽉 찼어요"
	elif not valid_name(p_name):
		reason = "닉네임을 확인하세요"
	if reason != "":
		print("REJECT ", id, " ", reason)
		_rejected.rpc_id(id, reason)
		await get_tree().create_timer(0.3).timeout
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	seats.append({"peer": id, "name": p_name.strip_edges(), "face": posmod(p_face, 4)})
	print("SEATED ", seats.size(), " ", p_name.strip_edges())
	_accepted.rpc_id(id)
	_to_seated(_sync_seats, [seats])


@rpc("authority", "call_remote", "reliable")
func _accepted() -> void:
	_joining = false
	state = State.LOBBY
	print("JOINED ", addr)
	joined.emit()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	print("JOIN_FAILED ", reason)
	_joining = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	state = State.NONE
	join_failed.emit(reason)


@rpc("authority", "call_local", "reliable")
func _sync_seats(p_seats: Array) -> void:
	seats = p_seats
	if not is_host() and state == State.LOBBY and seats.size() > 0:
		_remember(room_name(), addr)
	seats_changed.emit(seats)


@rpc("authority", "call_local", "reliable")
func _to_lobby(p_seats: Array) -> void:
	state = State.LOBBY
	seats = p_seats
	print("BACK_TO_LOBBY seats=", seats.size())
	seats_changed.emit(seats)
	lobby_returned.emit()


@rpc("authority", "call_local", "reliable")
func _begin(p_seats: Array) -> void:
	state = State.PLAYING
	seats = p_seats
	print("GAME_STARTED ", seats.size())
	game_started.emit(seats)

