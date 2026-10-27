extends Control
## Menú principal: nombre del tamer, Digimon compañero, modo, salas online (crear / unirse con código)
## y ranking del modo elegido. Guarda la elección en Session.

const PAPER := Color(0.98, 0.96, 0.9)
const INK := Color(0.12, 0.1, 0.14)
const CARD := Vector2(130, 158)
const SIDE := 104.0

var _name_edit := LineEdit.new()
var _selected := 0
var _cards: Array[Rect2] = []
var _sprites: Array[AnimatedSprite2D] = []
var _font := ThemeDB.fallback_font
var _play_rect := Rect2()
var _mode_rects: Array[Rect2] = []
var _code_edit := LineEdit.new()
var _host_rect := Rect2()
var _join_rect := Rect2()
var _leave_rect := Rect2()
var _ranking: Array = []
var _ranking_mode := ""
var _error := ""
const MODES := [["clasico", "Clásico", "15 min · 4 jefes"], ["supervivencia", "Supervivencia", "Infinito · hitos cada 5 min"]]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Music.play("menu")
	_selected = maxi(Session.CHARACTERS.find(Session.character), 0)
	_name_edit.text = Session.player_name
	_name_edit.max_length = 14
	_name_edit.placeholder_text = "Tu nombre"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_size_override("font_size", 12)
	add_child(_name_edit)
	_code_edit.max_length = 4
	_code_edit.placeholder_text = "CÓDIGO"
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.add_theme_font_size_override("font_size", 11)
	add_child(_code_edit)
	Net.lobby_changed.connect(queue_redraw)
	Net.room_error.connect(func(msg): _error = msg)
	Net.leaderboard_loaded.connect(func(rows): _ranking = rows)
	for c in Session.CHARACTERS:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = DigimonDB.sprite_frames(c.line[1])
		s.play("idle")
		s.centered = false
		s.scale = Vector2(1.6, 1.6)
		add_child(s)
		_sprites.append(s)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	_name_edit.size = Vector2(160, 22)
	_name_edit.position = Vector2((size.x - 160) / 2, 92)
	_cards.clear()
	var n := Session.CHARACTERS.size()
	var gap := 14.0
	var x := (size.x - (n * CARD.x + (n - 1) * gap)) / 2
	for i in n:
		var r := Rect2(x + i * (CARD.x + gap), 132, CARD.x, CARD.y)
		_cards.append(r)
		var info := DigimonDB.species(Session.CHARACTERS[i].line[1])
		var anchor: Vector2 = info["anchor"]
		_sprites[i].position = Vector2(r.get_center().x, r.position.y + 80) - anchor * _sprites[i].scale
	_play_rect = Rect2((size.x - 140) / 2, size.y - 44, 140, 30)
	var left := Rect2(8, 132, SIDE, CARD.y)
	_host_rect = Rect2(left.position + Vector2(6, 22), Vector2(SIDE - 12, 20))
	_code_edit.position = left.position + Vector2(6, 64)
	_code_edit.size = Vector2(SIDE - 12, 20)
	_join_rect = Rect2(left.position + Vector2(6, 88), Vector2(SIDE - 12, 20))
	_leave_rect = Rect2(left.position + Vector2(6, CARD.y - 26), Vector2(SIDE - 12, 20))
	_mode_rects.clear()
	for k in MODES.size():
		_mode_rects.append(Rect2(size.x / 2 - 210 + k * 330, size.y - 44, 90, 30))
	queue_redraw()


func _process(_delta: float) -> void:
	_code_edit.visible = not Net.online
	if _ranking_mode != Session.mode:
		_ranking_mode = Session.mode
		_ranking = []
		Net.load_leaderboard(Session.mode)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _cards.size():
			if _cards[i].has_point(event.position):
				_selected = i
		for k in _mode_rects.size():
			if _mode_rects[k].has_point(event.position):
				Session.mode = MODES[k][0]
		if _play_rect.has_point(event.position):
			_start()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_selected = posmod(_selected - 1, _cards.size())
			KEY_RIGHT, KEY_D:
				_selected = posmod(_selected + 1, _cards.size())
			KEY_TAB:
				Session.mode = "supervivencia" if Session.mode == "clasico" else "clasico"
			KEY_ENTER, KEY_KP_ENTER:
				_start()


func _save_choice() -> void:
	Session.player_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Tamer"
	Session.character = Session.CHARACTERS[_selected]
	Session.save()


func _start() -> void:
	_save_choice()
	if Net.online:
		if Net.is_host:
			Net.players[1] = Net._me()
			Net.start_game()
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _online(host: bool) -> void:
	_error = ""
	if not Net.webrtc_available():
		_error = "El online funciona en el navegador (dijimones.pages.dev)"
		return
	_save_choice()
	if host:
		Net.host_room()
	elif _code_edit.text.strip_edges().length() == 4:
		Net.join_room(_code_edit.text)
	else:
		_error = "Poné el código de 4 letras"


func _draw() -> void:
	# fondo: cielo y pasto de papel
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.74, 0.88, 0.97))
	draw_rect(Rect2(0, size.y * 0.62, size.x, size.y * 0.38), Color(0.5, 0.75, 0.4))
	draw_rect(Rect2(0, size.y * 0.62, size.x, 3), PAPER)
	# título
	var t := "DIJIMONES"
	var fs := 40
	var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2((size.x - tw) / 2, 56)
	draw_string_outline(_font, tp + Vector2(3, 3), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.3))
	draw_string_outline(_font, tp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, PAPER)
	draw_string(_font, tp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.55, 0.15))
	_center("Sobreviví en el Digital World", 74, 11, INK)
	_center("Nombre del tamer", 88, 9, INK)
	# tarjetas de Digimon
	for i in _cards.size():
		var r := _cards[i]
		var c: CharacterData = Session.CHARACTERS[i]
		var sel := i == _selected
		draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.3))
		draw_rect(r, PAPER if not sel else Color(1, 0.95, 0.75))
		if sel:
			draw_rect(r.grow(2), Color(1, 0.6, 0.15), false, 3.0)
		_center(c.display_name, r.position.y + 94, 14, INK, r)
		_center(" > ".join(c.line), r.position.y + 108, 8, Color(0.4, 0.35, 0.5), r)
		_center("Vida %d · Vel %d" % [c.max_hp, c.speed], r.position.y + 121, 8, Color(0.4, 0.35, 0.5), r)
		_center(c.starting_weapon.display_name, r.position.y + 133, 9, Color(0.75, 0.35, 0.1), r)
		draw_multiline_string(_font, Vector2(r.position.x + 6, r.position.y + 143), c.description,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 7, 2, Color(0.35, 0.3, 0.35))
	# modo de juego
	for k in _mode_rects.size():
		var r := _mode_rects[k]
		var sel: bool = Session.mode == MODES[k][0]
		draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.3))
		draw_rect(r, Color(0.35, 0.55, 0.95) if sel else PAPER)
		_center(MODES[k][1], r.position.y + 13, 10, Color.WHITE if sel else INK, r)
		_center(MODES[k][2], r.position.y + 25, 7, Color(1, 1, 1, 0.85) if sel else Color(0.4, 0.35, 0.5), r)
	_draw_online()
	_draw_ranking()
	if _error != "":
		_center(_error, 124, 9, Color(0.85, 0.15, 0.1))
	# botón jugar
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
	draw_rect(Rect2(_play_rect.position + Vector2(3, 3), _play_rect.size), Color(0, 0, 0, 0.3))
	draw_rect(_play_rect, Color(1, 0.6, 0.15) * pulse)
	draw_rect(_play_rect, PAPER, false, 2.0)
	var play_text := "¡JUGAR!"
	if Net.online:
		play_text = "¡EMPEZAR!" if Net.is_host else "Esperando…"
	_center(play_text, _play_rect.position.y + 21, 16, Color.WHITE)
	_center("Mover: WASD/flechas · Saltar: Espacio · Especial: R · Zoom: rueda o Q/E · Mejoras: 1/2/3 · Música: M · Modo: Tab",
		size.y - 6, 8, Color(0.1, 0.25, 0.1))


## Panel online a la izquierda: crear sala / unirse con código, o el lobby si ya estás en una.
func _draw_online() -> void:
	var r := Rect2(8, 132, SIDE, CARD.y)
	_panel(r)
	_center("Jugar online", r.position.y + 14, 10, INK, r)
	if not Net.online:
		_button(_host_rect, "Crear sala", Color(0.35, 0.55, 0.95))
		_center("o unite con un código:", r.position.y + 58, 7, Color(0.4, 0.35, 0.5), r)
		_button(_join_rect, "Unirse", Color(0.35, 0.7, 0.4))
		draw_multiline_string(_font, r.position + Vector2(6, 124), "Hasta 4 jugadores. XP compartida, revivís a tus amigos.",
			HORIZONTAL_ALIGNMENT_CENTER, SIDE - 12, 7, 3, Color(0.4, 0.35, 0.5))
		return
	_center("Sala", r.position.y + 30, 8, Color(0.4, 0.35, 0.5), r)
	_center(Net.room, r.position.y + 50, 20, Color(0.85, 0.4, 0.1), r)
	var y := r.position.y + 66
	for peer_id in Net.players:
		var pl: Dictionary = Net.players[peer_id]
		_center("%s%s (%s)" % ["★ " if int(peer_id) == 1 else "", pl["name"], pl["character"]], y, 8, INK, r)
		y += 11
	draw_multiline_string(_font, Vector2(r.position.x + 6, r.end.y - 40), Net.status, HORIZONTAL_ALIGNMENT_CENTER, SIDE - 12, 7, 2, Color(0.4, 0.35, 0.5))
	_button(_leave_rect, "Salir de la sala", Color(0.75, 0.3, 0.3))


## Ranking (Supabase) del modo elegido a la derecha.
func _draw_ranking() -> void:
	var r := Rect2(size.x - SIDE - 8, 132, SIDE, CARD.y)
	_panel(r)
	_center("Ranking · %s" % ("Clásico" if Session.mode == "clasico" else "Superviv."), r.position.y + 14, 9, INK, r)
	if _ranking.is_empty():
		_center("¡Sé el primero!", r.position.y + 40, 8, Color(0.4, 0.35, 0.5), r)
		return
	var y := r.position.y + 28
	for k in mini(_ranking.size(), 10):
		var row: Dictionary = _ranking[k]
		var secs := int(row.get("seconds", 0))
		var line := "%d. %s %d:%02d" % [k + 1, str(row.get("name", "?")).substr(0, 9), secs / 60, secs % 60]
		draw_string(_font, Vector2(r.position.x + 6, y), line, HORIZONTAL_ALIGNMENT_LEFT, SIDE - 10, 8,
			Color(0.75, 0.45, 0.05) if k == 0 else INK)
		y += 12


func _panel(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, PAPER)


func _button(r: Rect2, text: String, color: Color) -> void:
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, color)
	_center(text, r.position.y + 14, 10, Color.WHITE, r)


func _center(text: String, y: float, font_size: int, color: Color, within := Rect2()) -> void:
	var area := within if within.size != Vector2.ZERO else Rect2(0, 0, size.x, size.y)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 6, font_size).x
	draw_string(_font, Vector2(area.position.x + (area.size.x - tw) / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 6, font_size, color)
