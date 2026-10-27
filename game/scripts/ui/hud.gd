extends Control
## HUD moderno (paneles de vidrio oscuro, barras redondeadas): vida, armas y chips con nivel,
## especial (R), XP, reloj, kills, próximo jefe, barras de jefes, compañeros y carteles.

const SLOT := 28.0

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
var end_hint := "R: jugar de nuevo · Esc: menú"
## peer_id -> Player: compañeros en co-op
var team := {}

var _font := UIStyle.font()
var _bold := UIStyle.font_bold()
var _shown_hp := 1.0
var _glass := UIStyle.panel(UIStyle.BG, 10, UIStyle.BORDER, 8)
var _glass_small := UIStyle.panel(UIStyle.BG, 7, UIStyle.BORDER, 5)


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
	_draw_team()
	if player.dead and end_text == "":
		_pill("¡Caíste! Un compañero te revive quedándose cerca", size.y * 0.72, 11, UIStyle.BAD)
	if banner_time > 0.0:
		var a := clampf(banner_time * 3.0, 0.0, 1.0)
		_pill(banner, size.y * 0.22, 14, Color(UIStyle.WARN, a), a)
	if end_text != "":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.65))
		var card := Rect2(size.x / 2 - 150, size.y / 2 - 70, 300, 140)
		draw_style_box(UIStyle.panel(UIStyle.BG_SOLID, 16, Color(1, 1, 1, 0.12), 20), card)
		_text_c(end_text, Vector2(size.x / 2, card.position.y + 42), 24, UIStyle.ACCENT, true)
		var m := int(time) / 60
		var s := int(time) % 60
		_text_c("Nivel %d   ·   %d kills   ·   %02d:%02d" % [player.level, kills, m, s], Vector2(size.x / 2, card.position.y + 74), 12, UIStyle.TEXT)
		_text_c(end_hint, Vector2(size.x / 2, card.position.y + 110), 10, UIStyle.MUTED)


# --- partes ----------------------------------------------------------------------------------------

func _draw_top() -> void:
	var w := size.x
	# XP: barra fina arriba de todo
	UIStyle.draw_bar(self, Rect2(8, 6, w - 16, 6), float(player.xp) / player.xp_to_next(), Color(0.35, 0.82, 1.0))
	# reloj y kills en una pastilla
	var m := int(time) / 60
	var s := int(time) % 60
	var top := Rect2(w / 2 - 54, 16, 108, 24)
	draw_style_box(_glass_small, top)
	_text_c("%02d:%02d" % [m, s], Vector2(w / 2 - 14, top.position.y + 17), 15, UIStyle.TEXT, true)
	_text("☠ %d" % kills, Vector2(w / 2 + 16, top.position.y + 16), 10, UIStyle.MUTED)
	if not next_boss.is_empty() and bosses.is_empty():
		var left := maxi(ceili(next_boss[1]), 0)
		var t := "Próximo jefe: %s en %d:%02d" % [next_boss[0], left / 60, left % 60]
		var urgent: bool = next_boss[1] <= 10.0
		var col := UIStyle.BAD if urgent and fmod(Time.get_ticks_msec() * 0.004, 1.0) < 0.5 else UIStyle.MUTED
		_text_c(t, Vector2(w / 2, top.end.y + 13), 9, col)


func _draw_bosses() -> void:
	var y := 46.0
	for b in bosses:
		var bw := 240.0
		var x := (size.x - bw) / 2
		draw_style_box(_glass_small, Rect2(x - 8, y, bw + 16, 26))
		_text(b[0], Vector2(x, y + 11), 9, UIStyle.TEXT, true)
		UIStyle.draw_bar(self, Rect2(x, y + 15, bw, 6), b[1], UIStyle.BAD)
		y += 30.0


## Vida: panel abajo a la izquierda con especie, nivel, barra grande y números.
func _draw_health() -> void:
	var card := Rect2(8, size.y - 58, 190, 50)
	draw_style_box(_glass, card)
	_text(player.species(), card.position + Vector2(10, 17), 12, UIStyle.TEXT, true)
	var lvl := "Nv %d" % player.level
	_text(lvl, card.position + Vector2(card.size.x - 10 - _bold.get_string_size(lvl, 0, -1, 11).x, 17), 11, UIStyle.ACCENT, true)
	if player_name != "":
		_text(player_name, card.position + Vector2(10, 45), 8, UIStyle.MUTED)
	var bar := Rect2(card.position + Vector2(10, 23), Vector2(card.size.x - 20, 12))
	var frac := player.hp / player.stats.max_hp
	var hp_color := UIStyle.GOOD if frac > 0.5 else (UIStyle.WARN if frac > 0.25 else UIStyle.BAD)
	UIStyle.draw_bar(self, bar, frac, hp_color, Color(0, 0, 0, 0.5), _shown_hp)
	_text_c("%d / %d" % [ceili(player.hp), ceili(player.stats.max_hp)], bar.get_center() + Vector2(0, 4), 9, Color.WHITE, true)


## Armas y chips abajo al centro: tarjeta redondeada por cada uno, con iniciales y nivel.
func _draw_slots() -> void:
	var items := []
	for w in arsenal.weapons:
		items.append([w.display_name, arsenal.weapons[w], w.max_level, w.color, true])
	for p in arsenal.passives:
		items.append([p.display_name, arsenal.passives[p], p.max_level, Color(0.55, 0.62, 0.85), false])
	if items.is_empty():
		return
	var gap := 5.0
	var total := items.size() * (SLOT + gap) - gap
	var x := (size.x - total) / 2
	var y := size.y - SLOT - 14
	draw_style_box(_glass, Rect2(x - 7, y - 6, total + 14, SLOT + 16))
	for it in items:
		var r := Rect2(x, y, SLOT, SLOT)
		var c: Color = it[3]
		var sb := UIStyle.panel(c.darkened(0.15) if it[4] else c.darkened(0.45), 7, Color(1, 1, 1, 0.25), 0)
		draw_style_box(sb, r)
		var words := Array(String(it[0]).split(" "))
		var initials := "".join(words.map(func(s): return s.substr(0, 1)))
		_text_c(initials.substr(0, 2), r.get_center() + Vector2(0, 2), 10, Color.WHITE, true)
		# nivel abajo a la derecha y barrita de progreso
		_text(str(it[1]), r.position + Vector2(SLOT - 9, SLOT - 3), 8, UIStyle.WARN, true)
		UIStyle.draw_bar(self, Rect2(r.position.x + 3, r.end.y + 2, SLOT - 6, 3), float(it[1]) / it[2], UIStyle.WARN, Color(0, 0, 0, 0.5))
		x += SLOT + gap


## Especial abajo a la derecha: anillo que se llena y brilla cuando está listo (tecla R).
func _draw_special() -> void:
	var c := Vector2(size.x - 36, size.y - 34)
	var r := 22.0
	draw_circle(c, r + 4, Color(0, 0, 0, 0.35))
	draw_circle(c, r + 2, UIStyle.BG_SOLID)
	var col := player.character.special_color
	draw_arc(c, r - 3, 0, TAU, 48, Color(1, 1, 1, 0.08), 5.0, true)
	if player.special > 0.0:
		draw_arc(c, r - 3, -PI / 2, -PI / 2 + TAU * player.special, 48, col, 5.0, true)
	if player.special_ready():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
		draw_circle(c, r - 7, Color(col, 0.25 + 0.25 * pulse))
		_pill(player.special_name(), c.y - r - 8, 9, col, 1.0, c.x)
	_text_c("R", c + Vector2(0, 6), 16, Color.WHITE, true)


## Compañeros (co-op): nombre, especie y vida, arriba a la izquierda.
func _draw_team() -> void:
	if team.size() <= 1:
		return
	var y := 20.0
	for p in team.values():
		if p == player:
			continue
		var r := Rect2(8, y, 140, 30)
		draw_style_box(_glass_small, r)
		_text(p.player_name, r.position + Vector2(8, 12), 9, UIStyle.TEXT, true)
		_text(p.species(), r.position + Vector2(r.size.x - 8 - _font.get_string_size(p.species(), 0, -1, 8).x, 12), 8, UIStyle.MUTED)
		var bar := Rect2(r.position + Vector2(8, 17), Vector2(r.size.x - 16, 6))
		if p.dead:
			UIStyle.draw_bar(self, bar, p.revive, UIStyle.GOOD.lightened(0.3))
		else:
			UIStyle.draw_bar(self, bar, p.hp / maxf(p.stats.max_hp, 1.0), UIStyle.GOOD)
		y += 34.0


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
	# la cámara 3D da píxeles de pantalla; el HUD está en unidades de la resolución base (canvas_items)
	var sp := get_viewport().get_final_transform().affine_inverse() * view.camera.unproject_position(world)
	var margin := 30.0
	var area := Rect2(Vector2(margin, margin + 30), size - Vector2(margin * 2, margin * 2 + 80))
	if area.has_point(sp):
		return
	var c := area.get_center()
	var dir := (sp - c).normalized()
	var t := minf(absf(area.size.x / 2 / dir.x) if dir.x != 0.0 else INF, absf(area.size.y / 2 / dir.y) if dir.y != 0.0 else INF)
	var at := c + dir * t
	var col := stones.color_of(best)
	draw_circle(at, 13, Color(0, 0, 0, 0.3))
	draw_circle(at, 11, UIStyle.BG_SOLID)
	draw_colored_polygon(PackedVector2Array([at + dir * 8, at + dir.orthogonal() * 5 - dir * 2, at - dir.orthogonal() * 5 - dir * 2]), col)
	var d := int(player.position.distance_to(stones.pos[best]) / PaperView.PX)
	_text_c("%d m" % d, at - dir * 22 + Vector2(0, 3), 8, Color.WHITE, true)


# --- helpers -------------------------------------------------------------------------------------

## Pastilla redondeada con texto centrado.
func _pill(t: String, y: float, font_size: int, color: Color, alpha := 1.0, cx := -1.0) -> void:
	var center_x := size.x / 2 if cx < 0.0 else cx
	var tw := _bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var r := Rect2(center_x - tw / 2 - 12, y - font_size - 5, tw + 24, font_size + 13)
	var sb := UIStyle.panel(Color(UIStyle.BG_SOLID, 0.9 * alpha), int(r.size.y / 2), Color(color, 0.5 * alpha), 8)
	draw_style_box(sb, r)
	draw_string(_bold, Vector2(center_x - tw / 2, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))


func _text(t: String, pos: Vector2, font_size: int, color := Color.WHITE, bold := false) -> void:
	var f := _bold if bold else _font
	draw_string_outline(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.45))
	draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_c(t: String, center: Vector2, font_size: int, color := Color.WHITE, bold := false) -> void:
	var f := _bold if bold else _font
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(t, Vector2(center.x - tw / 2, center.y), font_size, color, bold)
