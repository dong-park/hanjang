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
signal room_emptied()  ## 전용 방에서 판 중 모두 나가 대기실로 되돌아갔을 때 (방 프로세스만 받는다)
signal owner_changed(who: String)  ## 방 주인이 바뀌었을 때 (전용 방 접속자가 받는다). 나머지 사람 화면에 문구를 띄운다
signal peer_rejoined(peer: int, seat: int)  ## 판 중 나갔던 자리가 같은 닉네임으로 돌아왔을 때 (방장만 받는다)

enum State { NONE, LOBBY, PLAYING }

## 판 중 끊긴 자리가 돌아와도 되는지 판정한다. Session이 규칙 엔진 판정으로 바꿔 끼운다.
var can_rejoin: Callable = func(_seat: int) -> bool: return false

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
const MIN_PLAYERS := 2
const MAX_NAME := 8
const RECENT_PATH := "user://recent_rooms.json"
const RECENT_MAX := 5
const TOKEN_PATH := "user://tokens.json"
const MAX_ROOM_NAME := 12
## 끊김 감지: 서버가 PING_EVERY 초마다 ping을 보내고, DEAD_AFTER 초 동안 응답이 없으면 끊긴 것으로 본다.
## 클라이언트도 서버 ping이 DEAD_AFTER 초 안 오면 끊긴 것으로 본다. 와이파이만 꺼진 FIN 없는 끊김도 20초 안에 잡는다.
const PING_EVERY := 3.0
const DEAD_AFTER := 12.0
## 이름에 쓸 수 없는 말 (닉네임·방 이름 공통). 소문자로 견준다.
const BANNED := ["씨발", "시발", "병신", "개새끼", "좆", "fuck", "shit"]

var port := DEFAULT_PORT
var state: State = State.NONE
var seats: Array = []
var my_name := ""
var my_face := 0
var addr := ""          ## 대기실에 보여 줄 방 주소
var dedicated := false  ## 전용 방 모드: 방 프로세스는 자리를 갖지 않고 판정만 한다. 시작·다시 하기는 '방 주인'이 요청한다
var owner_peer := 1          ## 방 주인 peer id. 맥 앱 LAN 방장은 1, 전용 방은 맨 앞 자리의 접속자
var room_code := ""
var room_name_override := ""  ## 전용 방 이름. 비면 방 주인 닉네임으로 '○○의 방'을 만든다
var room_public := false
var room_secret := ""         ## 전용 방 비밀값. 비어 있지 않으면 접속자가 같은 값을 내야 자리를 받는다
var my_secret := ""           ## 접속할 때 내는 방 비밀값 (--secret 또는 웹 주소의 ?secret=)
var token_path := TOKEN_PATH  ## 재접속 토큰 저장 파일. 시험은 --token-file 로 바꾼다
var skip_name_check := false  ## 시험용(--skip-name-check): 클라이언트 이름 검사를 건너뛰어 서버 검사를 확인한다
var owner_grace := 30.0       ## 방 주인이 끊기면 이만큼 기다렸다가 다음 사람에게 넘긴다 (시험은 --owner-grace)
var _grace_peer := 0          ## 끊겨서 기다리는 중인 옛 주인의 peer id
var _last_seen := {}          ## 서버: peer -> 마지막으로 응답한 시각(초)
var _last_ping := -1.0        ## 클라이언트: 서버 ping을 마지막으로 받은 시각(초). 음수면 아직 접속 전
var _ping_clock := 0.0
var _tokens := {}             ## 서버만: 닉네임 -> 재접속 토큰. 자리 목록에는 싣지 않아 다른 접속자에게 가지 않는다
var _joining := false
var relay_base := ""          ## 관리 서비스 주소(http[s]://호스트[:포트]). 웹은 페이지를 연 주소, 시험은 --relay=. 비면 옛 LAN 흐름
var via_relay := false        ## 관리 서비스(/ws/코드)로 들어간 연결인가


func _ready() -> void:
	if OS.has_feature("web"):
		var o = JavaScriptBridge.eval("window.location.origin")
		relay_base = str(o) if o != null else ""
		var s = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('secret')")
		if s != null:
			my_secret = str(s)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(func():
		_go_title("방이 닫혔어요. 서버가 다시 시작됐을 수 있어요" if via_relay else "방장이 나갔어요"))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(dt: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if is_host():
		_ping_clock += dt
		if _ping_clock < PING_EVERY:
			return
		_ping_clock = 0.0
		for p in multiplayer.get_peers():
			if _now() - _last_seen.get(p, _now()) > DEAD_AFTER:
				print("DROP_DETECTED t=%.3f" % Time.get_unix_time_from_system())
				multiplayer.multiplayer_peer.disconnect_peer(p)
			else:
				_ping.rpc_id(p)
	elif _last_ping >= 0.0 and _now() - _last_ping > DEAD_AFTER:
		print("DROP_DETECTED t=%.3f" % Time.get_unix_time_from_system())
		_last_ping = -1.0
		_go_title("연결이 끊겼어요")


@rpc("authority", "call_remote", "reliable")
func _ping() -> void:
	_last_ping = _now()
	_pong.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _pong() -> void:
	_last_seen[multiplayer.get_remote_sender_id()] = _now()


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func valid_name(n: String) -> bool:
	return name_problem(n, MAX_NAME) == ""


## 닉네임·방 이름 규칙. 어긋나면 사용자에게 보일 이유 문구, 괜찮으면 빈 문자열.
func name_problem(n: String, max_len: int) -> String:
	var t := n.strip_edges()
	if t.length() < 1:
		return "이름을 적어 주세요"
	if t.length() > max_len:
		return "%d자까지 쓸 수 있어요" % max_len
	for i in t.length():
		var c := t.unicode_at(i)
		if c >= 0x1F000 or (c >= 0x2600 and c <= 0x27BF) or c == 0xFE0F or c == 0x200D:
			return "이모지는 쓸 수 없어요"
	var low := t.to_lower()
	for w in BANNED:
		if low.contains(w):
			return "쓸 수 없는 말이 들어 있어요"
	return ""


## 서버 로그에는 전용 방에서 닉네임을 남기지 않는다.
func log_name(n: String) -> String:
	return "" if dedicated else n


func _load_tokens() -> Dictionary:
	if not FileAccess.file_exists(token_path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(token_path))
	return d if d is Dictionary else {}


func _token_key() -> String:
	return addr + "|" + my_name


func _save_token(t: String) -> void:
	var d := _load_tokens()
	d[_token_key()] = t
	var f := FileAccess.open(token_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


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


## 전용 방(헤드리스 서버): 자리 없이 연결만 받는다. 첫 접속자가 방 주인이 된다.
func host_dedicated(p_code: String, p_public: bool) -> bool:
	var peer := WebSocketMultiplayerPeer.new()
	if peer.create_server(port, "127.0.0.1") != OK:  ## 관리 서비스만 이 포트에 닿는다
		return false
	multiplayer.multiplayer_peer = peer
	dedicated = true
	room_code = p_code
	room_public = p_public
	state = State.LOBBY
	seats = []
	owner_peer = 0
	print("HOST_READY dedicated port=", port, " code=", p_code, " public=", p_public)
	return true


## 지금 내가 시작·다시 하기·대기실로를 누를 수 있는 사람인가 (LAN 방장 또는 전용 방의 방 주인).
func can_control() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() == owner_peer


func join_room(p_name: String, p_face: int, p_addr: String) -> bool:
	var why := "" if skip_name_check else name_problem(p_name, MAX_NAME)
	if why != "":
		join_failed.emit(why)
		return false
	if p_addr.strip_edges() == "" or _joining:
		return false
	my_name = p_name.strip_edges()
	my_face = p_face
	addr = p_addr.strip_edges()
	via_relay = addr.contains("/ws/")
	var peer := WebSocketMultiplayerPeer.new()
	if peer.create_client(ws_url(addr, port)) != OK:
		join_failed.emit("접속을 시작하지 못했어요")
		return false
	multiplayer.multiplayer_peer = peer
	_joining = true
	return true


func ws_url(p_addr: String, p_port: int) -> String:
	## 방 주소 규칙: 입력은 "192.168.0.5"(포트 7777 기본) 또는 "192.168.0.5:7778". ws:// 로 붙는다.
	## "wss://이름"은 터널 같은 https 주소용이라 그대로 쓴다.
	var a := p_addr.strip_edges()
	if a.begins_with("wss://"):
		return a
	a = a.trim_prefix("ws://")
	if a.contains(":") or a.contains("/"):
		return "ws://" + a
	return "ws://%s:%d" % [a, p_port]


## 관리 서비스의 방 웹소켓 주소 (https 페이지면 wss://, 아니면 ws://)
func relay_ws(code: String) -> String:
	return relay_base.replace("https://", "wss://").replace("http://", "ws://") + "/ws/" + code


## 웹 주소의 ?room=1234 (공유 링크). 4자리 숫자가 아니면 빈 문자열.
func link_room() -> String:
	if not OS.has_feature("web"):
		return ""
	var r = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('room')")
	var c := str(r) if r != null else ""
	return c if c.length() == 4 and c.is_valid_int() else ""


## 대기실에 보일 방 표시: 관리 서비스 방은 코드, 그 밖은 접속 주소
func room_label() -> String:
	return "방 코드 " + addr.get_slice("/ws/", 1) if via_relay else "방 주소 " + addr


func leave() -> void:
	## 자리를 비우고 연결을 닫는다. 방장이 부르면 접속자는 모두 첫 화면으로 간다.
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_reset()


func start_game() -> bool:
	## 방장만, 2명 이상일 때만 된다.
	if not is_host():
		if can_control():
			_ask.rpc_id(1, "start")
		return false
	return _do_start()


func _do_start() -> bool:
	if state != State.LOBBY or seats.size() < MIN_PLAYERS:
		print("START_BLOCKED seats=", seats.size())
		return false
	state = State.PLAYING
	print("START_OK seats=", seats.size())
	_to_seated(_begin, [seats])
	return true


func back_to_lobby() -> void:
	if not is_host():
		if can_control():
			_ask.rpc_id(1, "lobby")
		return
	state = State.LOBBY
	for i in range(seats.size() - 1, -1, -1):
		if seats[i].get("gone", false):
			seats.remove_at(i)
	_to_seated(_to_lobby, [seats])


## 다시 하기: 같은 사람끼리 바로 다음 판. 나간 자리는 비우고, 둘 미만이면 대기실로 간다.
func replay() -> void:
	if not is_host():
		if can_control():
			_ask.rpc_id(1, "replay")
		return
	if state != State.PLAYING:
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
	if room_name_override != "":
		return room_name_override
	return "%s의 방" % seats[0].name if seats.size() > 0 else ""


func lan_ips() -> PackedStringArray:
	## 집 와이파이 주소(192.168.)를 먼저, 그다음 10., 마지막에 172.(Docker 172.17. 같은 가상 망이 많다).
	var out := PackedStringArray()
	for prefix in ["192.168.", "10.", "172."]:
		for a in IP.get_local_addresses():
			if a.begins_with(prefix) and not a.begins_with("172.17.") and not out.has(a):
				out.append(a)
	for a in IP.get_local_addresses():
		if a.begins_with("172.17.") and not out.has(a):
			out.append(a)
	return out


## 웹 빌드: 페이지를 연 주소가 곧 방장 주소다(D7=A). 웹이 아니면 빈 문자열.
func page_host() -> String:
	if not OS.has_feature("web"):
		return ""
	var room = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('room')")
	if room != null and str(room) != "":
		return str(room)
	var h = JavaScriptBridge.eval("window.location.hostname")
	return str(h) if h != null else ""


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
	_last_ping = -1.0
	state = State.NONE
	seats = []
	owner_peer = 1
	_joining = false
	via_relay = false
	if not dedicated:
		room_name_override = ""  ## 관리 서비스 방에서 받아 둔 이름은 방을 나가면 버린다


func _go_title(reason: String) -> void:
	print("LEFT_TO_TITLE ", reason)
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_reset()
	left_to_title.emit(reason)


func _on_connected() -> void:
	_last_ping = _now()
	_hello.rpc_id(1, my_name, my_face, str(_load_tokens().get(_token_key(), "")), my_secret)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	_joining = false
	print("JOIN_FAILED 접속하지 못했어요")
	join_failed.emit("접속하지 못했어요. 주소를 확인하세요")


func _on_peer_connected(id: int) -> void:
	_last_seen[id] = _now()
	# 웹소켓 서버는 접속 수 상한 인자가 없다. ENet 때와 같은 상한(MAX_PLAYERS + 3)을 넘는 접속은 바로 끊는다.
	if is_host() and multiplayer.get_peers().size() > MAX_PLAYERS + 3:
		multiplayer.multiplayer_peer.disconnect_peer(id, true)


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	_last_seen.erase(id)
	for i in seats.size():
		if seats[i].peer == id:
			if state == State.PLAYING:
				seats[i]["gone"] = true
				print("PEER_LEFT_IN_GAME ", id)
				peer_left.emit(id)
				if dedicated and id == owner_peer and owner_grace > 0.0:
					_start_grace(id)  ## 주인 폰이 잠겼을 수 있다. 돌아올 때까지 기다린다
				else:
					_recompute_owner()
				if dedicated and seats.all(func(x): return x.get("gone", false)):
					print("ROOM_EMPTY")
					_grace_peer = 0
					seats = []
					state = State.LOBBY
					owner_peer = 0
					room_emptied.emit()
			else:
				seats.remove_at(i)
				print("SEAT_FREED ", id, " seats=", seats.size())
				_to_seated(_sync_seats, [seats])
				if dedicated and seats.is_empty():
					owner_peer = 0
			return


func _to_seated(fn: Callable, args: Array) -> void:
	## 자리에 앉은 접속자에게만 보낸다 (방장 본인은 로컬 호출).
	var me := multiplayer.get_unique_id()
	_recompute_owner()
	for s in seats.duplicate():
		if s.peer == me:
			fn.callv(args)
		else:
			fn.rpc_id(s.peer, args[0])
	if dedicated:  ## 방 프로세스는 자리가 없어도 상태를 따라가야 Session이 판을 연다
		fn.callv(args)


## 방 주인은 자리를 지키는 동안 그대로다. 나가면 판 중 나가지 않은 맨 앞 자리로 넘어간다. 전용 방에서만 바뀐다.
## 주인이 끊겨 기다리는 30초 동안은 넘기지 않는다. 접속자에게는 _set_owner로 알리고, 넘어가면 문구를 보낸다.
func _recompute_owner() -> void:
	if not dedicated or (_grace_peer != 0 and _grace_peer == owner_peer):
		return
	if seats.any(func(s): return s.peer == owner_peer and not s.get("gone", false)):
		return
	var o := 0
	var who := ""
	for s in seats:
		if not s.get("gone", false):
			o = s.peer
			who = s.name
			break
	if o == owner_peer:
		return
	var had_owner := owner_peer != 0
	owner_peer = o
	if had_owner and o != 0:
		print("OWNER_TRANSFER t=%.3f" % Time.get_unix_time_from_system())
	for s in seats:
		if not s.get("gone", false):
			_set_owner.rpc_id(s.peer, o)
			if had_owner and o != 0:
				_owner_changed.rpc_id(s.peer, who)


func _start_grace(old: int) -> void:
	_grace_peer = old
	print("OWNER_GRACE_START t=%.3f" % Time.get_unix_time_from_system())
	await get_tree().create_timer(owner_grace).timeout
	if _grace_peer != old:
		return  ## 그 사이 돌아왔거나 방이 비었다
	_grace_peer = 0
	_recompute_owner()


@rpc("authority", "call_remote", "reliable")
func _owner_changed(who: String) -> void:
	print("OWNER_CHANGED ", who)
	owner_changed.emit(who)


@rpc("any_peer", "call_remote", "reliable")
func _ask(what: String) -> void:
	## 전용 방: 방 주인이 보낸 요청만 받는다. 자리는 보낸 peer id로만 정한다.
	if not is_host() or not dedicated or multiplayer.get_remote_sender_id() != owner_peer:
		print("ASK_IGNORED ", what, " from=", multiplayer.get_remote_sender_id())
		return
	match what:
		"start": _do_start()
		"replay": replay()
		"lobby": back_to_lobby()


@rpc("authority", "call_remote", "reliable")
func _set_owner(p_owner: int) -> void:
	owner_peer = p_owner
	if p_owner == multiplayer.get_unique_id():
		print("OWNER_IS_ME")


@rpc("any_peer", "call_remote", "reliable")
func _hello(p_name: String, p_face: int, p_token: String, p_secret: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	for s in seats:
		if s.peer == id:
			return
	var nm := p_name.strip_edges()
	for k in _tokens.keys():  ## 자리가 없어진 이름의 토큰은 버린다
		if not seats.any(func(s): return s.name == k):
			_tokens.erase(k)
	var idx := -1
	for i in seats.size():
		if seats[i].name == nm:
			idx = i
			break
	## 같은 닉네임이라도 토큰이 맞아야 그 자리의 주인이다. 호스트 자리(토큰 없음)는 누구도 되찾지 못한다.
	var owns: bool = idx >= 0 and p_token != "" and _tokens.get(nm, "") == p_token
	var reason := ""
	if room_secret != "" and p_secret != room_secret:
		reason = "방을 못 찾았어요"
	elif idx >= 0 and not owns:
		reason = "이미 쓰는 이름이에요"
	elif owns:  ## 같은 브라우저가 돌아왔다. 아직 안 끊긴 옛 접속은 내보내고 자리를 넘겨받는다
		var old: int = seats[idx].peer
		if state == State.PLAYING:
			if not seats[idx].get("gone", false):
				seats[idx]["gone"] = true
				peer_left.emit(old)
			if can_rejoin.call(idx):
				seats[idx].erase("gone")
				seats[idx]["peer"] = id
				print("REJOINED ", id, " seat=", idx, " ", log_name(nm))
				if old == owner_peer:  ## 기다리던 주인이 돌아왔다
					owner_peer = id
					_grace_peer = 0
				_recompute_owner()
				_rejoined.rpc_id(id, seats, p_token)
				if dedicated:
					_set_owner.rpc_id(id, owner_peer)
				peer_rejoined.emit(id, idx)
				if old != id and multiplayer.get_peers().has(old):
					multiplayer.multiplayer_peer.disconnect_peer(old)
				return
			reason = "지금 게임 중이에요"
		else:
			seats[idx]["peer"] = id
			seats[idx]["face"] = posmod(p_face, 4)
			print("SEAT_TAKEN_BACK ", id, " ", log_name(nm))
			if old != id and multiplayer.get_peers().has(old):
				multiplayer.multiplayer_peer.disconnect_peer(old)
			_accepted.rpc_id(id, p_token)
			_to_seated(_sync_seats, [seats])
			return
	elif state == State.PLAYING:
		reason = "지금 게임 중이에요"
	elif seats.size() >= MAX_PLAYERS:
		reason = "방이 꽉 찼어요"
	else:
		reason = name_problem(nm, MAX_NAME)
	if reason != "":
		print("REJECT ", id, " ", reason)
		_rejected.rpc_id(id, reason)
		await get_tree().create_timer(0.3).timeout
		if multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(id):
			multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	seats.append({"peer": id, "name": nm, "face": posmod(p_face, 4)})
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	_tokens[nm] = token
	print("SEATED ", seats.size(), " ", log_name(nm))
	_accepted.rpc_id(id, token)
	_to_seated(_sync_seats, [seats])


@rpc("authority", "call_remote", "reliable")
func _rejoined(p_seats: Array, p_token: String) -> void:
	_joining = false
	_save_token(p_token)
	print("REJOINED_OK")
	_begin(p_seats)


@rpc("authority", "call_remote", "reliable")
func _accepted(p_token: String) -> void:
	_joining = false
	_save_token(p_token)
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

