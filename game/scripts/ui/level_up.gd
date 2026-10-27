extends Control
## Menú de level up que NO pausa el juego (PRD 8.6): el jugador queda invulnerable
## mientras elige y, si no elige en TIMEOUT segundos, se elige una opción al azar.

signal chosen(option: Dictionary)
signal chosen_index(index: int)

const TIMEOUT := 5.0

var _options: Array = []
var _time_left := 0.0
var _queue := 0  # level ups pendientes
var _remote_queue: Array = []
var _font := ThemeDB.fallback_font
var _cards: Array[Rect2] = []

var options_provider: Callable
var auto_pick := false  # pruebas automáticas


func is_open() -> bool:
	return not _options.is_empty()


func enqueue() -> void:
	_queue += 1
	if not is_open():
		_open_next()


## Online (cliente): las opciones las arma el host.
func enqueue_options(options: Array) -> void:
	_remote_queue.append(options)
	if not is_open():
		_open_next()


func _open_next() -> void:
	if not _remote_queue.is_empty():
		_options = _remote_queue.pop_front()
		_time_left = TIMEOUT
		visible = true
		return
	if _queue <= 0:
		return
	_queue -= 1
	_options = options_provider.call()
	if _options.is_empty():
		_options = [{}]  # sin mejoras disponibles: curación
	_time_left = TIMEOUT
	visible = true
	if auto_pick:
		# como un jugador típico: primero armas (nuevas o mejoras), después chips
		var pick := 0
		for i in _options.size():
			if not _options[i].is_empty() and _options[i]["item"] is WeaponData:
				pick = i
				break
		_choose.call_deferred(pick)


func _choose(i: int) -> void:
	if i < 0 or i >= _options.size():
		return
	var option: Dictionary = _options[i]
	chosen_index.emit(i)
	_options = []
	visible = false
	chosen.emit(option)
	_open_next()


func _process(delta: float) -> void:
	if not is_open():
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_choose(randi() % _options.size())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _choose(0)
			KEY_2: _choose(1)
			KEY_3: _choose(2)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		for i in _cards.size():
			if _cards[i].has_point(local):
				_choose(i)


func _draw() -> void:
	_cards.clear()
	if not is_open():
		return
	var w := 200.0
	var h := 46.0
	var x := size.x - w - 10
	var y := 60.0
	var bold := UIStyle.font_bold()
	var header := Rect2(x, y - 26, w, 22)
	draw_style_box(UIStyle.panel(UIStyle.ACCENT, 8, Color(1, 1, 1, 0.25), 6), header)
	draw_string(bold, header.position + Vector2(10, 15), "¡Subiste de nivel!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	var secs := "%ds" % ceili(_time_left)
	draw_string(bold, header.position + Vector2(w - 10 - bold.get_string_size(secs, 0, -1, 10).x, 15), secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.85))
	for i in _options.size():
		var r := Rect2(x, y + i * (h + 6), w, h)
		_cards.append(r)
		var o: Dictionary = _options[i]
		var color := UIStyle.GOOD
		var title := "Curar +30 de vida"
		var desc := "No quedan mejoras disponibles"
		var is_new := false
		if not o.is_empty():
			var item = o["item"]
			color = item.color if item is WeaponData else Color(0.55, 0.62, 0.85)
			title = item.display_name
			desc = item.description
			is_new = o["level"] == 1
		draw_style_box(UIStyle.panel(UIStyle.BG_SOLID, 10, Color(color, 0.6), 8), r)
		# ícono redondo con la tecla
		var ic := r.position + Vector2(20, h / 2)
		draw_circle(ic, 13, color.darkened(0.2))
		draw_string(bold, ic + Vector2(-4, 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_string(bold, r.position + Vector2(40, 17), title, HORIZONTAL_ALIGNMENT_LEFT, w - 50, 11, UIStyle.TEXT)
		var tag := "NUEVO" if is_new else ("Nv %d" % o["level"] if not o.is_empty() else "")
		if tag != "":
			var tw := bold.get_string_size(tag, 0, -1, 8).x
			var tr := Rect2(r.end.x - tw - 16, r.position.y + 7, tw + 10, 13)
			draw_style_box(UIStyle.panel(UIStyle.ACCENT if is_new else Color(1, 1, 1, 0.12), 6, Color(0, 0, 0, 0), 0), tr)
			draw_string(bold, tr.position + Vector2(5, 10), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
		draw_string(UIStyle.font(), r.position + Vector2(40, 33), desc, HORIZONTAL_ALIGNMENT_LEFT, w - 50, 9, UIStyle.MUTED)
