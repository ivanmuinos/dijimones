extends Control
## Menú principal: nombre del tamer y elección del Digimon compañero. Guarda la elección en Session.

const PAPER := Color(0.98, 0.96, 0.9)
const INK := Color(0.12, 0.1, 0.14)
const CARD := Vector2(150, 158)

var _name_edit := LineEdit.new()
var _selected := 0
var _cards: Array[Rect2] = []
var _sprites: Array[AnimatedSprite2D] = []
var _font := ThemeDB.fallback_font
var _play_rect := Rect2()


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
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _cards.size():
			if _cards[i].has_point(event.position):
				_selected = i
		if _play_rect.has_point(event.position):
			_start()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_selected = posmod(_selected - 1, _cards.size())
			KEY_RIGHT, KEY_D:
				_selected = posmod(_selected + 1, _cards.size())
			KEY_ENTER, KEY_KP_ENTER:
				_start()


func _start() -> void:
	Session.player_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Tamer"
	Session.character = Session.CHARACTERS[_selected]
	Session.save()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


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
	# botón jugar
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
	draw_rect(Rect2(_play_rect.position + Vector2(3, 3), _play_rect.size), Color(0, 0, 0, 0.3))
	draw_rect(_play_rect, Color(1, 0.6, 0.15) * pulse)
	draw_rect(_play_rect, PAPER, false, 2.0)
	_center("¡JUGAR!", _play_rect.position.y + 21, 16, Color.WHITE)
	_center("Mover: WASD/flechas · Saltar: Espacio · Especial: R · Zoom: rueda o Q/E · Mejoras: 1/2/3 · Música: M",
		size.y - 6, 8, Color(0.1, 0.25, 0.1))


func _center(text: String, y: float, font_size: int, color: Color, within := Rect2()) -> void:
	var area := within if within.size != Vector2.ZERO else Rect2(0, 0, size.x, size.y)
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 6, font_size).x
	draw_string(_font, Vector2(area.position.x + (area.size.x - tw) / 2, y), text, HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 6, font_size, color)
