extends Control
## HUD de papel: vida grande, armas y chips abajo con su nivel, medidor del especial (R),
## barra de XP, reloj, kills, barras de jefes y mensajes grandes.

const PAPER := Color(0.98, 0.96, 0.9)
const INK := Color(0.12, 0.1, 0.14)
const SLOT := 26.0

var player: Player
var arsenal: Arsenal
var view: PaperView
var stones: HolyStones
var player_name := ""
var time := 0.0
var kills := 0
## [nombre, vida 0..1] de cada jefe vivo
var bosses: Array = []
## [nombre, segundos] del próximo jefe (vacío si no quedan)
var next_boss: Array = []
var banner := ""
var banner_time := 0.0
var end_text := ""

var _font := ThemeDB.fallback_font
var _shown_hp := 1.0


func show_banner(text: String, seconds := 2.5) -> void:
	banner = text
	banner_time = seconds


func _process(delta: float) -> void:
	banner_time = maxf(banner_time - delta, 0.0)
	if player:
		_shown_hp = move_toward(_shown_hp, player.hp / player.stats.max_hp, delta * 0.8)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	_draw_top()
	_draw_bosses()
	_draw_health()
	_draw_slots()
	_draw_special()
	_draw_stone_arrow()
	if banner_time > 0.0:
		_paper_label(banner, size.y * 0.24, 15, Color(1, 0.85, 0.3))
	if end_text != "":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		_paper_label(end_text, size.y * 0.4, 24, Color(1, 0.85, 0.3))
		var m := int(time) / 60
		var s := int(time) % 60
		_paper_label("Nivel %d · %d kills · %02d:%02d" % [player.level, kills, m, s], size.y * 0.53, 12, INK)
		_paper_label("R: jugar de nuevo · Esc: menú", size.y * 0.63, 11, INK)


# --- partes ----------------------------------------------------------------------------------------

func _draw_top() -> void:
	var w := size.x
	# XP: tira de papel arriba de todo
	draw_rect(Rect2(0, 0, w, 7), PAPER)
	draw_rect(Rect2(1, 1, w - 2, 5), Color(0.15, 0.2, 0.3))
	draw_rect(Rect2(1, 1, (w - 2) * float(player.xp) / player.xp_to_next(), 5), Color(0.35, 0.85, 1.0))
	var m := int(time) / 60
	var s := int(time) % 60
	_text_c("%02d:%02d" % [m, s], Vector2(w / 2, 26), 16, Color.WHITE)
	_text("☠ %d" % kills, Vector2(w - 58, 24), 12, Color.WHITE)
	if not next_boss.is_empty() and bosses.is_empty():
		var left := maxi(ceili(next_boss[1]), 0)
		var t := "Próximo jefe: %s en %d:%02d" % [next_boss[0], left / 60, left % 60]
		var urgent: bool = next_boss[1] <= 10.0
		var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var r := Rect2((w - tw) / 2 - 6, 31, tw + 12, 13)
		_paper(r)
		if urgent and fmod(Time.get_ticks_msec() * 0.004, 1.0) < 0.5:
			draw_rect(r, Color(1, 0.3, 0.25))
		draw_string(_font, r.position + Vector2(6, 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color.WHITE if urgent else Color(0.55, 0.15, 0.15))


func _draw_bosses() -> void:
	var y := 36.0
	for b in bosses:
		var bw := 220.0
		var x := (size.x - bw) / 2
		_text_c(b[0], Vector2(size.x / 2, y + 2), 10, Color.WHITE)
		draw_rect(Rect2(x - 2, y + 5, bw + 4, 9), PAPER)
		draw_rect(Rect2(x, y + 7, bw, 5), Color(0.25, 0.08, 0.1))
		draw_rect(Rect2(x, y + 7, bw * b[1], 5), Color(0.9, 0.2, 0.3))
		y += 20.0


## Vida: tarjeta de papel abajo a la izquierda con especie, nivel, barra grande y números.
func _draw_health() -> void:
	var card := Rect2(6, size.y - 50, 168, 44)
	_paper(card)
	_text(player.species(), card.position + Vector2(8, 14), 11, INK)
	_text("Nv %d" % player.level, card.position + Vector2(card.size.x - 38, 14), 11, Color(0.35, 0.3, 0.5))
	if player_name != "":
		_text(player_name, card.position + Vector2(8, 41), 8, Color(0.45, 0.42, 0.5))
	var bar := Rect2(card.position + Vector2(8, 19), Vector2(card.size.x - 16, 11))
	draw_rect(bar, Color(0.25, 0.08, 0.1))
	var frac := player.hp / player.stats.max_hp
	# la parte clara es el daño reciente, que se vacía de a poco
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _shown_hp, bar.size.y)), Color(1, 0.85, 0.85))
	var hp_color := Color(0.3, 0.85, 0.35) if frac > 0.5 else (Color(0.95, 0.75, 0.2) if frac > 0.25 else Color(0.95, 0.25, 0.25))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), hp_color)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, 3)), Color(1, 1, 1, 0.35))
	_text_c("%d / %d" % [ceili(player.hp), ceili(player.stats.max_hp)], bar.get_center() + Vector2(0, 4), 9, Color.WHITE)


## Armas y chips abajo al centro: tarjeta por cada uno, con iniciales y puntitos de nivel.
func _draw_slots() -> void:
	var items := []
	for w in arsenal.weapons:
		items.append([w.display_name, arsenal.weapons[w], w.max_level, w.color, true])
	for p in arsenal.passives:
		items.append([p.display_name, arsenal.passives[p], p.max_level, Color(0.55, 0.6, 0.75), false])
	var total := items.size() * (SLOT + 4)
	var x := (size.x - total) / 2
	var y := size.y - SLOT - 12
	for it in items:
		var r := Rect2(x, y, SLOT, SLOT)
		_paper(r)
		var inner := r.grow(-3)
		var c: Color = it[3]
		draw_rect(inner, c if it[4] else c.darkened(0.2))
		var words := Array(String(it[0]).split(" "))
		var initials := "".join(words.map(func(s): return s.substr(0, 1)))
		_text_c(initials.substr(0, 2), inner.get_center() + Vector2(0, 4), 10, Color.WHITE)
		# puntos de nivel debajo
		var lvl: int = it[1]
		var max_lvl: int = it[2]
		var dot_w := (SLOT - 4) / max_lvl
		for k in max_lvl:
			draw_rect(Rect2(r.position.x + 2 + k * dot_w, r.end.y + 2, dot_w - 1, 3), Color(1, 0.85, 0.3) if k < lvl else Color(0, 0, 0, 0.4))
		x += SLOT + 4


## Medidor del especial abajo a la derecha: se llena y brilla cuando está listo (tecla R).
func _draw_special() -> void:
	var c := Vector2(size.x - 34, size.y - 30)
	var r := 20.0
	draw_circle(c, r + 3, PAPER)
	draw_circle(c, r, Color(0.15, 0.12, 0.2))
	var col := player.character.special_color
	if player.special > 0.0:
		draw_arc(c, r * 0.6, -PI / 2, -PI / 2 + TAU * player.special, 32, col, r * 0.8)
	if player.special_ready():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
		draw_arc(c, r + 5, 0, TAU, 32, Color(col, pulse), 2.5)
		_text_c(player.special_name(), c + Vector2(0, -r - 10), 9, Color.WHITE)
	_text_c("R", c + Vector2(0, 5), 14, Color.WHITE)


## Flecha en el borde de la pantalla hacia la Piedra Sagrada más cercana que no se ve.
func _draw_stone_arrow() -> void:
	if stones == null or view == null or stones.pos.is_empty():
		return
	var best := 0
	for i in stones.pos.size():
		if player.position.distance_to(stones.pos[i]) < player.position.distance_to(stones.pos[best]):
			best = i
	var world := PaperView.to_3d(stones.pos[best], 0.8)
	if view.camera.is_position_behind(world):
		return
	var sp := view.camera.unproject_position(world)
	var margin := 26.0
	var area := Rect2(Vector2(margin, margin + 20), size - Vector2(margin * 2, margin * 2 + 60))
	if area.has_point(sp):
		return
	var c := area.get_center()
	var dir := (sp - c).normalized()
	var t := minf(absf(area.size.x / 2 / dir.x) if dir.x != 0.0 else INF, absf(area.size.y / 2 / dir.y) if dir.y != 0.0 else INF)
	var at := c + dir * t
	var col := stones.color_of(best)
	var pts := PackedVector2Array([at + dir * 9, at + dir.orthogonal() * 6, at - dir.orthogonal() * 6])
	draw_colored_polygon(pts, PAPER)
	draw_colored_polygon(PackedVector2Array([at + dir * 6, at + dir.orthogonal() * 4 - dir, at - dir.orthogonal() * 4 - dir]), col)
	var d := int(player.position.distance_to(stones.pos[best]) / PaperView.PX)
	_text_c("%d m" % d, at - dir * 14 + Vector2(0, 4), 8, Color.WHITE)


# --- helpers -------------------------------------------------------------------------------------

func _paper(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, PAPER)


## Texto sobre una tira de papel centrada.
func _paper_label(t: String, y: float, font_size: int, color: Color) -> void:
	var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_paper(Rect2((size.x - tw) / 2 - 10, y - font_size - 4, tw + 20, font_size + 12))
	draw_string(_font, Vector2((size.x - tw) / 2, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		INK if color == INK else color.darkened(0.25))


func _text(t: String, pos: Vector2, font_size: int, color := Color.WHITE) -> void:
	if color == Color.WHITE:
		draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.8))
	draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_c(t: String, center: Vector2, font_size: int, color := Color.WHITE) -> void:
	var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(t, Vector2(center.x - tw / 2, center.y), font_size, color)
