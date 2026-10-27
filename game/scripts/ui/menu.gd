extends Control
## Menú principal: nombre del tamer, Digimon compañero, modo, salas online (crear / unirse con código)
## y ranking del modo elegido. Hecho con Controls reales y el estilo de UIStyle.

const MODES := [["clasico", "Clásico", "15 min · 4 jefes"], ["supervivencia", "Supervivencia", "Infinito · hitos cada 5 min"]]
const CARD := Vector2(136, 168)
const SIDE := 128.0
## Lienzo de diseño del menú: se escala para entrar entero en cualquier ventana (responsive).
const DESIGN := Vector2(760, 372)

var _selected := 0
var _content := Control.new()
var _title := Label.new()
var _subtitle := Label.new()
var _name_edit := LineEdit.new()
var _cards: Array[Button] = []
var _sprites: Array[AnimatedSprite2D] = []
var _mode_buttons: Array[Button] = []
var _play := Button.new()
var _error := Label.new()
# online
var _online_panel := PanelContainer.new()
var _offline_box := VBoxContainer.new()
var _lobby_box := VBoxContainer.new()
var _code_edit := LineEdit.new()
var _room_label := Label.new()
var _players_label := Label.new()
var _status_label := Label.new()
# ranking
var _ranking_panel := PanelContainer.new()
var _ranking_rows := VBoxContainer.new()
var _ranking_title := Label.new()
var _ranking_mode := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	Music.play("menu")
	_selected = maxi(Session.CHARACTERS.find(Session.character), 0)
	_build()
	Net.lobby_changed.connect(_refresh_online)
	Net.room_error.connect(func(msg): _show_error(msg))
	Net.leaderboard_loaded.connect(_fill_ranking)
	resized.connect(_layout)
	_layout()
	_refresh_online()


# --- construcción --------------------------------------------------------------------------------

func _build() -> void:
	add_child(_content)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.text = "DIJIMONES"
	_title.add_theme_font_override("font", UIStyle.font_bold())
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", UIStyle.ACCENT)
	_title.add_theme_color_override("font_outline_color", Color.WHITE)
	_title.add_theme_constant_override("outline_size", 12)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_title)
	_subtitle.text = "Sobreviví en el Digital World"
	_subtitle.add_theme_font_size_override("font_size", 11)
	_subtitle.add_theme_color_override("font_color", Color(0.08, 0.16, 0.32))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_subtitle)
	_name_edit.text = Session.player_name
	_name_edit.max_length = 14
	_name_edit.placeholder_text = "Tu nombre de tamer"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_name_edit)

	var group := ButtonGroup.new()
	for i in Session.CHARACTERS.size():
		var c: CharacterData = Session.CHARACTERS[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == _selected
		b.focus_mode = Control.FOCUS_NONE
		var normal := UIStyle.panel(UIStyle.BG, 14)
		var hover := UIStyle.panel(UIStyle.BG.lightened(0.08), 14, Color(1, 1, 1, 0.2))
		var sel := UIStyle.panel(Color(0.16, 0.12, 0.08, 0.92), 14, UIStyle.ACCENT)
		sel.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", sel)
		b.add_theme_stylebox_override("hover_pressed", sel)
		b.pressed.connect(func(): _selected = i)
		_content.add_child(b)
		_cards.append(b)
		var s := AnimatedSprite2D.new()
		s.sprite_frames = DigimonDB.sprite_frames(c.line[1])
		s.play("idle")
		s.centered = false
		s.scale = Vector2(1.6, 1.6)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_child(s)
		_sprites.append(s)
		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.position = Vector2(9, 76)
		info.size = Vector2(CARD.x - 18, CARD.y - 80)
		info.add_theme_constant_override("separation", 1)
		b.add_child(info)
		info.add_child(_label(c.display_name, 14, UIStyle.TEXT, true))
		var line := _label(" › ".join(c.line), 7, UIStyle.MUTED)
		line.clip_text = true
		line.custom_minimum_size.x = CARD.x - 18
		info.add_child(line)
		info.add_child(_label("Vida %d · Velocidad %d" % [c.max_hp, c.speed], 9, UIStyle.TEXT))
		info.add_child(_label(c.starting_weapon.display_name, 10, UIStyle.ACCENT, true))
		var d := _label(c.description, 7, UIStyle.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = CARD.x - 18
		d.max_lines_visible = 2
		info.add_child(d)

	var mode_group := ButtonGroup.new()
	for k in MODES.size():
		var m := Button.new()
		m.toggle_mode = true
		m.button_group = mode_group
		m.button_pressed = Session.mode == MODES[k][0]
		m.focus_mode = Control.FOCUS_NONE
		m.text = "%s\n%s" % [MODES[k][1], MODES[k][2]]
		m.add_theme_font_size_override("font_size", 9)
		var on := UIStyle.panel(UIStyle.ACCENT_2, 9, Color(1, 1, 1, 0.3))
		m.add_theme_stylebox_override("normal", UIStyle.panel(UIStyle.BG, 9))
		m.add_theme_stylebox_override("hover", UIStyle.panel(UIStyle.BG.lightened(0.1), 9))
		m.add_theme_stylebox_override("pressed", on)
		m.add_theme_stylebox_override("hover_pressed", on)
		m.pressed.connect(func(): Session.mode = MODES[k][0])
		_content.add_child(m)
		_mode_buttons.append(m)

	_play.text = "¡JUGAR!"
	_play.focus_mode = Control.FOCUS_NONE
	UIStyle.style_button(_play, UIStyle.ACCENT, 18)
	_play.pressed.connect(_start)
	_content.add_child(_play)

	_error.add_theme_color_override("font_color", UIStyle.BAD)
	_error.add_theme_font_size_override("font_size", 10)
	_error.add_theme_font_override("font", UIStyle.font_bold())
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_error)

	# panel online
	_content.add_child(_online_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_online_panel.add_child(box)
	box.add_child(_label("Jugar online", 13, UIStyle.TEXT, true))
	box.add_child(_offline_box)
	box.add_child(_lobby_box)
	_offline_box.add_theme_constant_override("separation", 5)
	var host := Button.new()
	host.text = "Crear sala"
	host.pressed.connect(func(): _online(true))
	_offline_box.add_child(host)
	_offline_box.add_child(_label("o unite con un código", 8, UIStyle.MUTED))
	_code_edit.max_length = 4
	_code_edit.placeholder_text = "CÓDIGO"
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.text_submitted.connect(func(_t): _online(false))
	_offline_box.add_child(_code_edit)
	var join := Button.new()
	join.text = "Unirse"
	UIStyle.style_button(join, UIStyle.GOOD.darkened(0.2), 12)
	join.pressed.connect(func(): _online(false))
	_offline_box.add_child(join)
	_offline_box.add_child(_label("Hasta 4 · XP compartida", 7, UIStyle.MUTED))
	_lobby_box.add_theme_constant_override("separation", 4)
	_lobby_box.add_child(_label("Código de la sala", 8, UIStyle.MUTED))
	_room_label.add_theme_font_override("font", UIStyle.font_bold())
	_room_label.add_theme_font_size_override("font_size", 24)
	_room_label.add_theme_color_override("font_color", UIStyle.ACCENT)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_box.add_child(_room_label)
	_players_label.add_theme_font_size_override("font_size", 9)
	_lobby_box.add_child(_players_label)
	_status_label.add_theme_font_size_override("font_size", 8)
	_status_label.add_theme_color_override("font_color", UIStyle.MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.x = SIDE - 16
	_lobby_box.add_child(_status_label)
	var leave := Button.new()
	leave.text = "Salir de la sala"
	UIStyle.style_button(leave, UIStyle.BAD.darkened(0.25), 10)
	leave.pressed.connect(func():
		Net.leave()
		_refresh_online())
	_lobby_box.add_child(leave)

	# ranking
	_content.add_child(_ranking_panel)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", 4)
	_ranking_panel.add_child(rbox)
	_ranking_title.add_theme_font_override("font", UIStyle.font_bold())
	_ranking_title.add_theme_font_size_override("font_size", 12)
	rbox.add_child(_ranking_title)
	rbox.add_child(_ranking_rows)

	var controls := _label("WASD mover · Espacio saltar · R especial · Q/E zoom · 1/2/3 mejoras · M música · Tab modo", 8, Color(1, 1, 1, 0.85))
	controls.name = "Controles"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(controls)


func _label(text: String, size_px: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UIStyle.font_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _layout() -> void:
	var w := DESIGN.x
	var k := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_content.size = DESIGN
	_content.scale = Vector2(k, k)
	_content.position = ((size - DESIGN * k) / 2).floor()
	_title.position = Vector2(0, 0)
	_title.size = Vector2(w, 60)
	_subtitle.position = Vector2(0, 58)
	_subtitle.size = Vector2(w, 16)
	_name_edit.size = Vector2(170, 22)
	_name_edit.position = Vector2((w - 170) / 2, 80)
	var n := _cards.size()
	var gap := 12.0
	var x := (w - (n * CARD.x + (n - 1) * gap)) / 2
	var top := 112.0
	for i in n:
		_cards[i].position = Vector2(x + i * (CARD.x + gap), top)
		_cards[i].size = CARD
		var info := DigimonDB.species(Session.CHARACTERS[i].line[1])
		var anchor: Vector2 = info["anchor"]
		_sprites[i].position = Vector2(CARD.x / 2, 72) - anchor * _sprites[i].scale
	_online_panel.position = Vector2(x - SIDE - 14, top)
	_ranking_panel.position = Vector2(x + n * CARD.x + (n - 1) * gap + 14, top)
	for p in [_online_panel, _ranking_panel]:
		p.reset_size()
		p.size = Vector2(SIDE, CARD.y)
	_error.position = Vector2(0, top + CARD.y + 6)
	_error.size = Vector2(w, 14)
	var bottom := top + CARD.y + 24
	_play.size = Vector2(150, 36)
	_play.position = Vector2((w - 150) / 2, bottom)
	for m in _mode_buttons.size():
		_mode_buttons[m].size = Vector2(124, 36)
		_mode_buttons[m].position = Vector2(w / 2 - 75 - 134 if m == 0 else w / 2 + 75 + 10, bottom)
	var controls: Label = _content.get_node("Controles")
	controls.position = Vector2(0, bottom + 44)
	controls.size = Vector2(w, 12)


# --- comportamiento ------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _ranking_mode != Session.mode:
		_ranking_mode = Session.mode
		_ranking_title.text = "Ranking · %s" % ("Clásico" if Session.mode == "clasico" else "Supervivencia")
		_fill_ranking([])
		Net.load_leaderboard(Session.mode)
	for k in _mode_buttons.size():
		_mode_buttons[k].set_pressed_no_signal(Session.mode == MODES[k][0])
	_play.text = "¡JUGAR!" if not Net.online else ("¡EMPEZAR!" if Net.is_host else "Esperando al host…")
	_play.disabled = Net.online and not Net.is_host
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _name_edit.has_focus() or _code_edit.has_focus():
			return
		match event.keycode:
			KEY_LEFT, KEY_A:
				_select(posmod(_selected - 1, _cards.size()))
			KEY_RIGHT, KEY_D:
				_select(posmod(_selected + 1, _cards.size()))
			KEY_TAB:
				Session.mode = "supervivencia" if Session.mode == "clasico" else "clasico"
			KEY_ENTER, KEY_KP_ENTER:
				_start()


func _select(i: int) -> void:
	_selected = i
	_cards[i].button_pressed = true


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
	_show_error("")
	if not Net.webrtc_available():
		_show_error("El online funciona en el navegador (dijimones.pages.dev)")
		return
	_save_choice()
	if host:
		Net.host_room()
	elif _code_edit.text.strip_edges().length() == 4:
		Net.join_room(_code_edit.text)
	else:
		_show_error("Poné el código de 4 letras de la sala")
	_refresh_online()


func _show_error(msg: String) -> void:
	_error.text = msg


func _refresh_online() -> void:
	_offline_box.visible = not Net.online
	_lobby_box.visible = Net.online
	_room_label.text = Net.room
	var lines := []
	for peer_id in Net.players:
		var pl: Dictionary = Net.players[peer_id]
		lines.append("%s · %s%s" % [pl["name"], str(pl["character"]).capitalize(), "  (host)" if int(peer_id) == 1 else ""])
	_players_label.text = "\n".join(lines)
	_status_label.text = Net.status
	# los PanelContainer crecen con el contenido pero no se achican solos
	for p in [_online_panel, _ranking_panel]:
		p.reset_size()
		p.size = Vector2(SIDE, CARD.y)


func _fill_ranking(rows: Array) -> void:
	_ranking_panel.reset_size()
	_ranking_panel.size = Vector2(SIDE, CARD.y)
	for c in _ranking_rows.get_children():
		c.queue_free()
	if rows.is_empty():
		_ranking_rows.add_child(_label("¡Sé el primero!", 9, UIStyle.MUTED))
		return
	for k in mini(rows.size(), 10):
		var row: Dictionary = rows[k]
		var secs := int(row.get("seconds", 0))
		var color := UIStyle.ACCENT if k == 0 else (UIStyle.TEXT if k < 3 else UIStyle.MUTED)
		_ranking_rows.add_child(_label("%d. %s  %d:%02d" % [k + 1, str(row.get("name", "?")).substr(0, 10), secs / 60, secs % 60], 9, color, k < 3))


func _draw() -> void:
	# fondo: cielo en degradé y colinas de papel que se mueven despacio
	var w := size.x
	var h := size.y
	for k in 12:
		draw_rect(Rect2(0, k * h / 12.0, w, h / 12.0 + 1), Color(0.36, 0.62, 0.95).lerp(Color(0.8, 0.92, 1.0), k / 12.0))
	var t := Time.get_ticks_msec() * 0.0002
	var colors := [Color(0.58, 0.8, 0.52), Color(0.46, 0.71, 0.43), Color(0.36, 0.6, 0.36)]
	for layer in 3:
		var pts := PackedVector2Array([Vector2(0, h)])
		var base := h * (0.6 + layer * 0.09)
		for k in 41:
			var x := w * k / 40.0
			pts.append(Vector2(x, base - 16 * sin(k * 0.45 + layer * 1.7 + t * (layer + 1)) - 8 * sin(k * 1.2 + layer)))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, colors[layer])
		draw_polyline(pts.slice(1, pts.size() - 1), Color(1, 1, 1, 0.55), 2.0, true)
