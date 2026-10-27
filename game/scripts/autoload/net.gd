extends Node
## Online: login de invitado y rankings en Supabase, y salas co-op de hasta 4 jugadores.
## Supabase Realtime solo presenta a los jugadores (señalización); el juego va directo entre navegadores
## por WebRTC, con el host corriendo la simulación (PRD 8.6). Todas las RPC del juego pasan por este nodo.

signal lobby_changed
signal room_error(message: String)
signal leaderboard_loaded(rows: Array)
## RPC de juego reenviadas a la escena (main.gd)
signal client_state(peer_id: int, state: Dictionary)
signal client_action(peer_id: int, kind: String, value: int)
signal snapshot(data: Dictionary)
signal event(kind: String, data: Dictionary)

const SUPABASE_URL := "https://jnclpopfpvdrjundvvzj.supabase.co"
## Clave pública por diseño (la seguridad la dan las políticas de supabase/schema.sql).
const SUPABASE_KEY := "sb_publishable_szGJbxzSwwIIW8iNOEmYxw_Cmebq22d"
const SESSION_PATH := "user://sesion.cfg"
const MAX_PLAYERS := 4
const ICE := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun.cloudflare.com:3478"]}]}
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var online := false
var is_host := false
var room := ""
## peer_id -> {"name": String, "character": String}
var players := {}
var status := ""

var access_token := ""
var user_id := ""

var _uid := ""  # id para la señalización (no es el de Supabase)
var _channel: RealtimeChannel
var _rtc: WebRTCMultiplayerPeer
var _conns := {}  # peer_id -> WebRTCPeerConnection
var _uid_of := {}  # peer_id -> uid (host)
var _pending_ice: Array = []  # candidatos que llegan antes que la oferta (cliente)


func _ready() -> void:
	_uid = _random_code(12)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_load_session()
	# sin ventana (pruebas automáticas) no hay red
	if access_token == "" and DisplayServer.get_name() != "headless":
		sign_in_guest()


# --- Supabase: login de invitado y rankings --------------------------------------------------------

func sign_in_guest() -> void:
	var res = await _request("/auth/v1/signup", HTTPClient.METHOD_POST, {})
	if res is Dictionary and res.has("access_token"):
		access_token = res["access_token"]
		user_id = res["user"]["id"]
		var cfg := ConfigFile.new()
		cfg.set_value("sesion", "token", access_token)
		cfg.set_value("sesion", "refresh", res.get("refresh_token", ""))
		cfg.set_value("sesion", "user", user_id)
		cfg.save(SESSION_PATH)


## Sube la run terminada al ranking (si hay sesión).
func submit_run(run: Dictionary) -> void:
	if access_token == "" or DisplayServer.get_name() == "headless":
		return
	run["user_id"] = user_id
	var res = await _request("/rest/v1/runs", HTTPClient.METHOD_POST, run, true)
	if res is Dictionary and res.get("code") == "PGRST301" or res is Dictionary and str(res.get("message", "")).contains("JWT"):
		# sesión vencida: nueva sesión de invitado y reintento
		access_token = ""
		await sign_in_guest()
		run["user_id"] = user_id
		await _request("/rest/v1/runs", HTTPClient.METHOD_POST, run, true)


func load_leaderboard(mode: String, stage := "file_island") -> void:
	var path := "/rest/v1/leaderboard?select=name,character,seconds,kills,level,players&stage=eq.%s&mode=eq.%s&order=seconds.desc,kills.desc&limit=10" % [stage, mode]
	var res = await _request(path, HTTPClient.METHOD_GET, {})
	leaderboard_loaded.emit(res if res is Array else [])


func _request(path: String, method: int, body: Dictionary, auth := false) -> Variant:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := ["apikey: " + SUPABASE_KEY, "Content-Type: application/json"]
	if auth and access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	if method == HTTPClient.METHOD_POST and path.begins_with("/rest/"):
		headers.append("Prefer: return=minimal")
	var err := http.request(SUPABASE_URL + path, headers, method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if err != OK:
		http.queue_free()
		return {}
	var result: Array = await http.request_completed
	http.queue_free()
	var text: String = result[3].get_string_from_utf8()
	if text.strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if parsed != null else {}


func _load_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SESSION_PATH) == OK:
		access_token = cfg.get_value("sesion", "token", "")
		user_id = cfg.get_value("sesion", "user", "")


# --- Salas -------------------------------------------------------------------------------------------

func webrtc_available() -> bool:
	return OS.has_feature("web")


func host_room() -> void:
	leave()
	online = true
	is_host = true
	room = _random_code(4)
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_server()
	multiplayer.multiplayer_peer = _rtc
	players = {1: _me()}
	status = "Esperando amigos…"
	_open_channel()
	lobby_changed.emit()


func join_room(code: String) -> void:
	leave()
	online = true
	is_host = false
	room = code.strip_edges().to_upper()
	status = "Buscando la sala %s…" % room
	_open_channel()
	lobby_changed.emit()
	# si el host no responde en 12 s, avisar
	await get_tree().create_timer(12.0).timeout
	if online and not is_host and _conns.is_empty() and room == code.strip_edges().to_upper():
		room_error.emit("No se encontró la sala %s (¿el código está bien?)" % room)


func leave() -> void:
	if _channel:
		_channel.close()
		_channel.queue_free()
		_channel = null
	for c in _conns.values():
		c.close()
	_conns.clear()
	_uid_of.clear()
	_pending_ice.clear()
	if _rtc:
		_rtc.close()
		_rtc = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	is_host = false
	room = ""
	players.clear()
	status = ""


func start_game() -> void:
	if is_host:
		start_game_rpc.rpc(players, Session.mode)


@rpc("authority", "call_local", "reliable")
func start_game_rpc(lobby: Dictionary, mode: String) -> void:
	players = lobby
	Session.mode = mode
	get_tree().change_scene_to_file("res://scenes/main.tscn")


@rpc("authority", "call_remote", "reliable")
func sync_lobby(lobby: Dictionary) -> void:
	players = lobby
	status = "¡Conectado! Esperando que el host arranque"
	lobby_changed.emit()


func _me() -> Dictionary:
	return {"name": Session.player_name, "character": Session.character.id}


func _open_channel() -> void:
	_channel = RealtimeChannel.new()
	add_child(_channel)
	_channel.joined.connect(_on_channel_joined)
	_channel.message.connect(_on_signal)
	_channel.failed.connect(func(msg): room_error.emit(msg))
	_channel.open(SUPABASE_URL, SUPABASE_KEY, "dijimones-" + room, access_token)


func _on_channel_joined() -> void:
	if not is_host:
		_channel.send("hola", {"uid": _uid, "jugador": _me()})


## Señalización: el host le ofrece una conexión WebRTC a cada jugador que saluda.
func _on_signal(ev: String, p: Dictionary) -> void:
	if is_host:
		match ev:
			"hola":
				if players.size() >= MAX_PLAYERS:
					_channel.send("lleno", {"to": p["uid"]})
					return
				var peer_id := 2
				while players.has(peer_id):
					peer_id += 1
				players[peer_id] = p["jugador"]
				_uid_of[peer_id] = p["uid"]
				var conn := _new_connection(peer_id, p["uid"])
				_rtc.add_peer(conn, peer_id)
				conn.create_offer()
				status = "%s se está conectando…" % p["jugador"]["name"]
				lobby_changed.emit()
			"sdp":
				if p.get("to") == "host" and _conns.has(int(p["peer_id"])):
					_conns[int(p["peer_id"])].set_remote_description(p["type"], p["sdp"])
			"ice":
				if p.get("to") == "host" and _conns.has(int(p["peer_id"])):
					_conns[int(p["peer_id"])].add_ice_candidate(p["media"], int(p["index"]), p["name"])
	else:
		if p.get("to") != _uid:
			return
		match ev:
			"sdp":
				var peer_id := int(p["peer_id"])
				_rtc = WebRTCMultiplayerPeer.new()
				_rtc.create_client(peer_id)
				multiplayer.multiplayer_peer = _rtc
				var conn := _new_connection(1, "host", peer_id)
				_rtc.add_peer(conn, 1)
				conn.set_remote_description(p["type"], p["sdp"])
				for c in _pending_ice:
					conn.add_ice_candidate(c["media"], int(c["index"]), c["name"])
				_pending_ice.clear()
				status = "Conectando con el host…"
				lobby_changed.emit()
			"ice":
				if _conns.has(1):
					_conns[1].add_ice_candidate(p["media"], int(p["index"]), p["name"])
				else:
					_pending_ice.append(p)
			"lleno":
				room_error.emit("La sala está llena (máximo %d)" % MAX_PLAYERS)
				leave()


## to = uid del destino; my_peer = peer id propio (cliente) para que el host sepa quién manda.
func _new_connection(peer_id: int, to: String, my_peer := 1) -> WebRTCPeerConnection:
	var conn := WebRTCPeerConnection.new()
	conn.initialize(ICE)
	var tag := peer_id if is_host else my_peer
	conn.session_description_created.connect(func(type: String, sdp: String):
		conn.set_local_description(type, sdp)
		_channel.send("sdp", {"to": to, "peer_id": tag, "type": type, "sdp": sdp}))
	conn.ice_candidate_created.connect(func(media: String, index: int, cname: String):
		_channel.send("ice", {"to": to, "peer_id": tag, "media": media, "index": index, "name": cname}))
	_conns[peer_id] = conn
	return conn


func _on_peer_connected(peer_id: int) -> void:
	if is_host:
		status = "%s entró a la sala" % players.get(peer_id, {}).get("name", "Alguien")
		sync_lobby.rpc(players)
		lobby_changed.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host:
		players.erase(peer_id)
		_conns.erase(peer_id)
		sync_lobby.rpc(players)
		event.emit("salio", {"peer": peer_id})
		lobby_changed.emit()
	elif peer_id == 1:
		room_error.emit("Se desconectó el host")
		event.emit("host_salio", {})


# --- RPC de juego --------------------------------------------------------------------------------------

## Cliente -> host: posición propia (cada uno mueve a su Digimon sin lag; co-op, sin anti-trampa).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func c_state(state: Dictionary) -> void:
	client_state.emit(multiplayer.get_remote_sender_id(), state)


## Cliente -> host: especial, elección de carta, etc.
@rpc("any_peer", "call_remote", "reliable")
func c_action(kind: String, value: int) -> void:
	client_action.emit(multiplayer.get_remote_sender_id(), kind, value)


## Host -> clientes: estado del mundo comprimido (~15 por segundo).
@rpc("authority", "call_remote", "unreliable_ordered")
func h_snapshot(bytes: PackedByteArray, size: int) -> void:
	var data = bytes_to_var(bytes.decompress(size, FileAccess.COMPRESSION_DEFLATE))
	if data is Dictionary:
		snapshot.emit(data)


## Host -> clientes: eventos (carteles, efectos, cartas de level up, fin de la run).
@rpc("authority", "call_remote", "reliable")
func h_event(kind: String, data: Dictionary) -> void:
	event.emit(kind, data)


func send_snapshot(data: Dictionary) -> void:
	var raw := var_to_bytes(data)
	h_snapshot.rpc(raw.compress(FileAccess.COMPRESSION_DEFLATE), raw.size())


func _random_code(n: int) -> String:
	var s := ""
	for i in n:
		s += CODE_CHARS[randi() % CODE_CHARS.length()]
	return s
