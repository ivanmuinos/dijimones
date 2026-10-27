class_name RealtimeChannel
extends Node
## Cliente mínimo de Supabase Realtime (protocolo Phoenix sobre WebSocket) para un canal de Broadcast.
## Lo usamos solo para la señalización de las salas: intercambiar ofertas WebRTC y candidatos ICE.

signal joined
signal message(event: String, payload: Dictionary)
signal failed(reason: String)

const HEARTBEAT := 25.0

var _ws := WebSocketPeer.new()
var _topic := ""
var _token := ""
var _ref := 0
var _heartbeat := 0.0
var _state := "idle"  # idle, connecting, joining, joined


func open(supabase_url: String, api_key: String, topic: String, access_token := "") -> void:
	_topic = "realtime:" + topic
	_token = access_token
	var url := supabase_url.replace("https://", "wss://") + "/realtime/v1/websocket?apikey=%s&vsn=1.0.0" % api_key
	var err := _ws.connect_to_url(url)
	if err != OK:
		failed.emit("No se pudo conectar al servidor de salas (%d)" % err)
		return
	_state = "connecting"


func send(event: String, payload: Dictionary) -> void:
	if _state == "joined":
		_send(_topic, "broadcast", {"type": "broadcast", "event": event, "payload": payload})


func close() -> void:
	if _state != "idle":
		_send(_topic, "phx_leave", {})
		_ws.close()
	_state = "idle"


func is_joined() -> bool:
	return _state == "joined"


func _process(delta: float) -> void:
	if _state == "idle":
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if _state == "connecting":
				_state = "joining"
				var payload := {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": ""}, "private": false}}
				if _token != "":
					payload["access_token"] = _token
				_send(_topic, "phx_join", payload)
			while _ws.get_available_packet_count() > 0:
				_handle(_ws.get_packet().get_string_from_utf8())
			_heartbeat += delta
			if _heartbeat >= HEARTBEAT:
				_heartbeat = 0.0
				_send("phoenix", "heartbeat", {})
		WebSocketPeer.STATE_CLOSED:
			var was := _state
			_state = "idle"
			if was != "idle":
				failed.emit("Se cortó la conexión con el servidor de salas (%d)" % _ws.get_close_code())


func _handle(text: String) -> void:
	var msg = JSON.parse_string(text)
	if not msg is Dictionary:
		return
	var event: String = msg.get("event", "")
	var payload = msg.get("payload", {})
	if event == "phx_reply" and msg.get("topic") == _topic and _state == "joining":
		if payload.get("status") == "ok":
			_state = "joined"
			joined.emit()
		else:
			failed.emit("El servidor rechazó la sala: %s" % JSON.stringify(payload.get("response", {})))
	elif event == "broadcast" and payload is Dictionary:
		message.emit(payload.get("event", ""), payload.get("payload", {}))
	elif event == "phx_error" or event == "system" and payload is Dictionary and payload.get("status") == "error":
		failed.emit("Error del servidor de salas: %s" % JSON.stringify(payload))


func _send(topic: String, event: String, payload: Dictionary) -> void:
	_ref += 1
	var ref := str(_ref)
	var msg := {"topic": topic, "event": event, "payload": payload, "ref": ref}
	if event == "phx_join":
		msg["join_ref"] = ref
	_ws.send_text(JSON.stringify(msg))
