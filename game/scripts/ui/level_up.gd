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
	var w := 170.0
	var h := 38.0
	var x := size.x - w - 8
	var y := 40.0
	draw_string(_font, Vector2(x, y - 6), "¡Subiste de nivel! (%.0f)" % ceilf(_time_left),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.95, 0.5))
	for i in _options.size():
		var r := Rect2(x, y + i * (h + 4), w, h)
		_cards.append(r)
		draw_rect(r, Color(0.08, 0.1, 0.2, 0.9))
		draw_rect(r, Color(0.5, 0.7, 1.0), false, 1.0)
		var o: Dictionary = _options[i]
		var title := "Curar +30 HP"
		var desc := ""
		if not o.is_empty():
			var item = o["item"]
			title = "%s  Nv %d" % [item.display_name, o["level"]]
			if o["level"] == 1:
				title = "NUEVO: " + item.display_name
			desc = item.description
		draw_string(_font, r.position + Vector2(6, 14), "%d. %s" % [i + 1, title], HORIZONTAL_ALIGNMENT_LEFT, w - 10, 11)
		draw_string(_font, r.position + Vector2(6, 29), desc, HORIZONTAL_ALIGNMENT_LEFT, w - 10, 9, Color(0.75, 0.8, 0.9))
