extends Node2D
## Run de un mapa: arma el mundo y corre todos los sistemas en un orden fijo por frame
## (simulación separada del dibujo, pensando en el co-op del PRD 8.6).

const DEFAULT_CHARACTER := preload("res://data/characters/agumon.tres")
const STAGE := preload("res://data/stages/file_island.tres")
const SPAWN_RADIUS := 380.0
const SHOCKWAVE_RADIUS := 170.0
const SHOCKWAVE_DAMAGE := 250.0
const SPECIAL_RADIUS := 220.0
const SPECIAL_DAMAGE := 220.0
## Carga del especial: por cada punto de XP y por cada kill.
const SPECIAL_PER_XP := 0.012
const SPECIAL_PER_KILL := 0.004
const ZOOM_STEP := 1.12
## Supervivencia: después de la duración del mapa sigue para siempre, con un jefe al azar cada MILESTONE.
const MILESTONE := 300.0

var character: CharacterData = DEFAULT_CHARACTER
var player := Player.new()
var enemies := EnemyField.new()
var projectiles := Projectiles.new()
var gems := XpGems.new()
var arsenal := Arsenal.new()
var hazards := Hazards.new()
var stones := HolyStones.new()
var survival := Session.mode == "supervivencia"
var terrain := Terrain.new(STAGE)
var hud := preload("res://scripts/ui/hud.gd").new()
var level_up := preload("res://scripts/ui/level_up.gd").new()
var view := PaperView.new()

var time := 0.0
var kills := 0
var running := true

var autotest := "--autotest" in OS.get_cmdline_user_args()
var _next_report := 60.0
var _spawn_timer := 0.0
var _bosses_spawned := {}
var _bosses_warned := {}
var _next_milestone := STAGE.duration


func _ready() -> void:
	randomize()
	Music.play("batalla")
	if Session.character:
		character = Session.character
	# la simulación es 2D (en píxeles); el dibujo lo hace PaperView en 3D
	for n in [gems, arsenal, enemies, projectiles]:
		add_child(n)
		n.visible = false
	add_child(player)
	player.modulate = Color.TRANSPARENT  # invisible pero sigue animando (PaperView lee el frame)
	add_child(view)

	player.setup(character)
	player.leveled_up.connect(func(_lvl): level_up.enqueue())
	player.digivolved.connect(_on_digivolved)
	player.died.connect(func(): _end("GAME OVER"))

	projectiles.enemies = enemies
	arsenal.player = player
	arsenal.enemies = enemies
	arsenal.projectiles = projectiles
	arsenal.add_weapon(character.starting_weapon)

	enemies.player_radius = player.radius()
	enemies.killed.connect(_on_enemy_killed)
	enemies.attack_slam.connect(hazards.slam)
	enemies.attack_shot.connect(hazards.shot)
	hazards.chest_opened.connect(_on_chest)
	stones.activated.connect(_on_stone)
	gems.collected.connect(_on_xp)

	var ui := CanvasLayer.new()
	add_child(ui)
	for c in [hud, level_up]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(c)
	hud.player = player
	hud.arsenal = arsenal
	hud.view = view
	hud.player_name = Session.player_name
	view.player = player
	view.enemies = enemies
	view.projectiles = projectiles
	view.gems = gems
	view.arsenal = arsenal
	view.hazards = hazards
	view.terrain = terrain
	view.stones = stones
	hud.stones = stones
	view.setup(STAGE)
	level_up.visible = false
	level_up.options_provider = arsenal.level_up_options
	level_up.chosen.connect(arsenal.apply)
	if survival:
		hud.show_banner("%s — Supervivencia: ¿cuánto aguantás?" % STAGE.display_name, 3.0)
	else:
		hud.show_banner("%s — sobreviví %d minutos" % [STAGE.display_name, int(STAGE.duration / 60)], 3.0)
	if autotest:
		player.use_autopilot = true
		level_up.auto_pick = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			view.zoom_by(1.0 / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			view.zoom_by(ZOOM_STEP)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q, KEY_MINUS:
				view.zoom_by(ZOOM_STEP)
			KEY_E, KEY_EQUAL, KEY_PLUS:
				view.zoom_by(1.0 / ZOOM_STEP)
			KEY_SPACE:
				player.jump()
			KEY_R:
				if running:
					_fire_special()
				else:
					get_tree().reload_current_scene()
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _process(delta: float) -> void:
	view.render(delta)
	if not running:
		return
	time += delta
	hud.time = time
	if level_up.is_open():
		player.invulnerable = 0.2
	if autotest:
		player.autopilot = _bot_direction()
	_move_player(delta)
	_spawn(delta)
	var contact := enemies.tick(delta, player.position)
	if not player.airborne():
		player.take_damage(contact)
	hazards.tick(delta, player)
	stones.tick(delta, player.position, _can_place_stone)
	arsenal.tick(delta)
	projectiles.tick(delta)
	enemies.remove_dead()
	gems.tick(delta, player.position, player.stats.magnet)
	hud.bosses = _boss_bars()
	hud.next_boss = _next_boss()
	if time >= STAGE.duration and running and not survival:
		_end("¡SOBREVIVISTE!")
	if autotest and time >= _next_report:
		_next_report += 60.0
		_report()


## Movimiento con terreno: los escalones más altos solo se suben saltando; se puede bajar siempre.
func _move_player(delta: float) -> void:
	var before := player.position
	player.tick(delta)
	_keep_on_land(player)
	var after := player.position
	if not _can_stand(after):
		# probar deslizar por cada eje contra el acantilado
		player.position = Vector2(after.x, before.y)
		if not _can_stand(player.position):
			player.position = Vector2(before.x, after.y)
			if not _can_stand(player.position):
				player.position = before
	player.tick_vertical(delta, terrain.height_at(player.position))


func _can_stand(pos: Vector2) -> bool:
	return terrain.height_at(pos) <= player.z + 0.05


func _spawn(delta: float) -> void:
	for b in STAGE.bosses:
		if time >= b.time and not _bosses_spawned.has(b):
			_bosses_spawned[b] = true
			enemies.spawn(b.enemy, _spawn_point(), 1.0)
			hud.show_banner("¡Apareció %s!" % b.enemy.label())
	if survival and time >= _next_milestone:
		_milestone()
	var wave: WaveData = STAGE.wave_at(time)
	if wave == null:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	# en Supervivencia, pasado el final del mapa las oleadas siguen creciendo
	var extra := maxf(time - STAGE.duration, 0.0)
	_spawn_timer = wave.interval * maxf(0.45, 1.0 - extra / 1200.0)
	var hp_mult := 1.0 + time / 180.0
	for k in wave.batch + int(extra / 120.0):
		enemies.spawn(wave.enemies.pick_random(), _spawn_point(), hp_mult)


## Hito de Supervivencia: jefe al azar más fuerte cada vez, y cofre al derrotarlo.
func _milestone() -> void:
	_next_milestone += MILESTONE
	var boss: EnemyData = STAGE.bosses.pick_random().enemy
	enemies.spawn(boss, _spawn_point(), 1.0 + time / 300.0)
	hud.show_banner("¡Hito %d:00! Aparece %s" % [int(time / 60), boss.label()], 3.0)


func _spawn_point() -> Vector2:
	var p := player.position + Vector2.RIGHT.rotated(randf() * TAU) * SPAWN_RADIUS
	if STAGE.water_from_x != INF:
		p.x = minf(p.x, (STAGE.water_from_x - 1.0) * PaperView.PX)
	return p


## El mar es el borde del mapa.
func _keep_on_land(node: Node2D) -> void:
	if STAGE.water_from_x != INF:
		node.position.x = minf(node.position.x, (STAGE.water_from_x - 1.0) * PaperView.PX)


func _on_xp(amount: int) -> void:
	player.add_xp(amount)
	player.add_special(amount * SPECIAL_PER_XP)


func _on_enemy_killed(at: Vector2, data: EnemyData) -> void:
	kills += 1
	hud.kills = kills
	player.add_special(SPECIAL_PER_KILL)
	gems.drop(at, data.xp)
	if data.boss:
		hazards.drop_chest(at)
		hud.show_banner("¡%s derrotado! Soltó un cofre" % data.label())


## Las piedras no aparecen arriba de acantilados ni en el mar.
func _can_place_stone(p: Vector2) -> bool:
	if STAGE.water_from_x != INF and p.x > (STAGE.water_from_x - 3.0) * PaperView.PX:
		return false
	return terrain.height_at(p) == 0.0


func _on_stone(_at: Vector2, reward: Dictionary) -> void:
	var before := player.stats.max_hp
	player.stats.add_bonus(reward["stat"], reward["value"])
	player.hp += player.stats.max_hp - before
	hud.show_banner("¡%s! %s" % [reward["name"], reward["text"]], 2.5)
	view.special(90.0, reward["color"])


## Cofre de jefe: 1 a 3 mejoras gratis (como en Vampire Survivors).
func _on_chest() -> void:
	var n: int = [1, 1, 2, 3].pick_random()
	hud.show_banner("¡Cofre! %d mejora%s" % [n, "s" if n > 1 else ""])
	for k in n:
		level_up.enqueue()


## Especial (R): explosión grande alrededor del jugador; la potencia sube con la etapa.
func _fire_special() -> void:
	if not player.special_ready() or player.dead:
		return
	player.special = 0.0
	var radius := SPECIAL_RADIUS * (1.0 + 0.25 * player.stage) * player.stats.area
	var damage := SPECIAL_DAMAGE * (1.0 + player.stage) * player.stats.might
	for i in enemies.in_circle(player.position, radius):
		enemies.hit(i, damage, player.position, 260.0)
	view.special(radius, character.special_color)
	player.play_once("ataque")
	hud.show_banner("¡%s!" % player.special_name(), 1.5)


## Digievolución: cura (lo hace Player), onda que limpia la pantalla y atrae toda la XP (PRD 5.2).
func _on_digivolved(from_species: String, to_species: String) -> void:
	hud.show_banner("¡%s digievoluciona a %s!" % [from_species, to_species], 3.0)
	view.shockwave(SHOCKWAVE_RADIUS)
	for i in enemies.in_circle(player.position, SHOCKWAVE_RADIUS):
		enemies.hit(i, SHOCKWAVE_DAMAGE, player.position, 200.0)
	gems.pull_all()
	enemies.player_radius = player.radius()


## [nombre, segundos que faltan] del próximo jefe; avisa fuerte a los 10 segundos.
func _next_boss() -> Array:
	var best: BossSpawn = null
	for b in STAGE.bosses:
		if not _bosses_spawned.has(b) and (best == null or b.time < best.time):
			best = b
	if best == null:
		if survival:
			return ["Hito sorpresa", _next_milestone - time]
		return []
	var left := best.time - time
	if left <= 10.0 and not _bosses_warned.has(best):
		_bosses_warned[best] = true
		hud.show_banner("¡%s llega en 10 segundos!" % best.enemy.label(), 3.0)
	return [best.enemy.label(), left]


func _boss_bars() -> Array:
	var out := []
	for i in enemies.count():
		var d := enemies.data_of(i)
		if d.boss:
			out.append([d.label(), enemies.hp[i] / enemies.max_hp[i]])
	return out


func _end(text: String) -> void:
	running = false
	if survival:
		text = "¡Aguantaste %d:%02d!" % [int(time) / 60, int(time) % 60]
	hud.end_text = text
	player.play_once("victoria" if text != "GAME OVER" else "golpe")
	if autotest:
		_report()
		print("[autotest] FIN: %s" % text)
		get_tree().quit()


## Bot simple: se aleja de los enemigos cercanos, salta los golpes al piso, usa el especial
## si está rodeado y si no hay peligro va hacia las gemas.
func _bot_direction() -> Vector2:
	for k in hazards.warn_pos.size():
		if player.position.distance_to(hazards.warn_pos[k]) < hazards.warn_radius[k] + 10.0 and hazards.warn_left[k] < 0.3:
			player.jump()
	if player.special_ready() and enemies.in_circle(player.position, 120.0).size() > 15:
		_fire_special()
	var flee := Vector2.ZERO
	for i in enemies.in_circle(player.position, 60.0):
		var away := player.position - enemies.pos[i]
		flee += away / maxf(away.length_squared(), 1.0)
	if flee != Vector2.ZERO:
		return (flee.normalized() + flee.normalized().orthogonal() * 0.6).normalized()
	var best := -1
	for i in gems.pos.size():
		if best < 0 or player.position.distance_squared_to(gems.pos[i]) < player.position.distance_squared_to(gems.pos[best]):
			best = i
	if best >= 0:
		return (gems.pos[best] - player.position).normalized()
	return Vector2.ZERO


## Prueba automática: `godot --headless --fixed-fps 60 --quit-after 60000 -- --autotest`
func _report() -> void:
	print("[autotest] %02d:%02d nv %d %s hp %d/%d | enemigos %d gemas %d | kills %d | %s" % [
		int(time / 60), int(time) % 60, player.level, player.species(), player.hp, player.stats.max_hp,
		enemies.count(), gems.pos.size(), kills,
		", ".join(arsenal.weapons.keys().map(func(w): return "%s %d" % [w.display_name, arsenal.weapons[w]]))])
