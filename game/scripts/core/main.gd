extends Node2D
## Run de un mapa: arma el mundo y corre todos los sistemas en un orden fijo por frame
## (simulación separada del dibujo). Soporta co-op online de hasta 4 (PRD 8.6):
## el host (o el único jugador, offline) simula todo; los clientes mueven a su propio Digimon,
## mandan su posición y dibujan lo que llega en los snapshots.

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
## Co-op: más jugadores, más enemigos y más vida (PRD 8.6).
const EXTRA_SPAWN_PER_PLAYER := 0.6
const REVIVE_RADIUS := 40.0
const REVIVE_TIME := 3.0
const SNAPSHOT_RATE := 15.0
const STATE_RATE := 20.0

var players := {}  # peer_id -> Player
var arsenals := {}  # peer_id -> Arsenal
var me: Player
var my_arsenal: Arsenal
var enemies := EnemyField.new()
var projectiles := Projectiles.new()
var gems := XpGems.new()
var hazards := Hazards.new()
var stones := HolyStones.new()
var terrain := Terrain.new(STAGE)
var hud := preload("res://scripts/ui/hud.gd").new()
var level_up := preload("res://scripts/ui/level_up.gd").new()
var view := PaperView.new()

var online := Net.online
var is_host := not Net.online or Net.is_host
var survival := Session.mode == "supervivencia"
var time := 0.0
var kills := 0
var running := true

var autotest := "--autotest" in OS.get_cmdline_user_args()
var _next_report := 60.0
var _spawn_timer := 0.0
var _bosses_spawned := {}
var _bosses_warned := {}
var _next_milestone := STAGE.duration
var _pending_options := {}  # peer_id -> Array de opciones ofrecidas (host)
var _net_timer := 0.0
var _submitted := false


func _ready() -> void:
	randomize()
	Music.play("batalla")
	for n in [gems, enemies, projectiles]:
		add_child(n)
		n.visible = false
	add_child(view)

	var lobby: Dictionary = Net.players if online else {1: {"name": Session.player_name, "character": Session.character.id}}
	var my_id := multiplayer.get_unique_id() if online else 1
	for peer_id in lobby:
		_add_player(int(peer_id), lobby[peer_id])
	me = players[my_id]
	my_arsenal = arsenals[my_id]

	projectiles.enemies = enemies
	enemies.killed.connect(_on_enemy_killed)
	enemies.attack_slam.connect(hazards.slam)
	enemies.attack_shot.connect(hazards.shot)
	hazards.chest_opened.connect(_on_chest)
	stones.activated.connect(_on_stone)
	gems.collected.connect(_on_xp)
	Net.client_state.connect(_on_client_state)
	Net.client_action.connect(_on_client_action)
	Net.snapshot.connect(_on_snapshot)
	Net.event.connect(_on_net_event)

	var ui := CanvasLayer.new()
	add_child(ui)
	for c in [hud, level_up]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(c)
	hud.player = me
	hud.arsenal = my_arsenal
	hud.view = view
	hud.stones = stones
	hud.player_name = me.player_name
	hud.team = players
	view.player = me
	view.team = players
	view.team_arsenals = arsenals
	view.enemies = enemies
	view.projectiles = projectiles
	view.gems = gems
	view.arsenal = my_arsenal
	view.hazards = hazards
	view.terrain = terrain
	view.stones = stones
	view.setup(STAGE)
	level_up.visible = false
	level_up.options_provider = my_arsenal.level_up_options
	if is_host:
		level_up.chosen.connect(my_arsenal.apply)
	else:
		level_up.chosen_index.connect(func(i): Net.c_action.rpc_id(1, "carta", i))
	if survival:
		hud.show_banner("%s — Supervivencia: ¿cuánto aguantás?" % STAGE.display_name, 3.0)
	else:
		hud.show_banner("%s — sobreviví %d minutos" % [STAGE.display_name, int(STAGE.duration / 60)], 3.0)
	if autotest:
		me.use_autopilot = true
		level_up.auto_pick = true


func _add_player(peer_id: int, info: Dictionary) -> void:
	var character := DEFAULT_CHARACTER
	for c in Session.CHARACTERS:
		if c.id == info.get("character", ""):
			character = c
	var p := Player.new()
	p.peer_id = peer_id
	p.player_name = info.get("name", "Tamer")
	add_child(p)
	p.modulate = Color.TRANSPARENT  # invisible pero sigue animando (PaperView lee el frame)
	p.setup(character)
	p.position = Vector2((peer_id - 1) * 40.0, 0)
	var a := Arsenal.new()
	a.player = p
	a.enemies = enemies
	a.projectiles = projectiles
	a.visible = false
	add_child(a)
	if is_host:
		a.add_weapon(character.starting_weapon)
		p.leveled_up.connect(func(_lvl): _offer_level_up(p))
		p.digivolved.connect(func(a_from, a_to): _on_digivolved(p, a_from, a_to))
	players[peer_id] = p
	arsenals[peer_id] = a


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
				me.jump()
			KEY_R:
				if running:
					if is_host:
						_fire_special(me)
					else:
						Net.c_action.rpc_id(1, "especial", 0)
				elif is_host:
					if online:
						Net.start_game()
					else:
						get_tree().reload_current_scene()
			KEY_ESCAPE:
				Net.leave()
				get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _process(delta: float) -> void:
	view.render(delta)
	if not running:
		return
	if level_up.is_open():
		me.invulnerable = 0.2
	if autotest:
		me.autopilot = _bot_direction()
	# cada uno mueve a su propio Digimon (también los clientes, sin esperar al host)
	if not me.dead:
		_move_player(me, delta)
	if not is_host:
		_net_timer += delta
		if _net_timer >= 1.0 / STATE_RATE:
			_net_timer = 0.0
			Net.c_state.rpc_id(1, {"p": me.position, "z": me.z, "f": me.floor_height, "l": me.facing_left(),
				"m": me.velocity != Vector2.ZERO, "menu": level_up.is_open()})
		return
	_simulate(delta)
	if online:
		_net_timer += delta
		if _net_timer >= 1.0 / SNAPSHOT_RATE:
			_net_timer = 0.0
			Net.send_snapshot(_snapshot())


## Simulación completa (host u offline).
func _simulate(delta: float) -> void:
	time += delta
	hud.time = time
	_spawn(delta)
	var alive := _alive()
	var targets := PackedVector2Array()
	var radii := PackedFloat32Array()
	var magnets := PackedFloat32Array()
	for p in alive:
		targets.append(p.position)
		radii.append(p.radius())
		magnets.append(p.stats.magnet)
	var contact := enemies.tick(delta, targets, radii)
	for k in alive.size():
		if not alive[k].airborne():
			alive[k].take_damage(contact[k])
	hazards.tick(delta, alive)
	stones.tick(delta, targets, _can_place_stone)
	for peer_id in arsenals:
		if not players[peer_id].dead:
			arsenals[peer_id].tick(delta)
	projectiles.tick(delta)
	enemies.remove_dead()
	gems.tick(delta, targets, magnets)
	_revives(delta)
	hud.bosses = _boss_bars()
	hud.next_boss = _next_boss()
	if _alive().is_empty():
		_end("GAME OVER")
	elif time >= STAGE.duration and not survival:
		_end("¡SOBREVIVISTE!")
	if autotest and time >= _next_report:
		_next_report += 60.0
		_report()


func _alive() -> Array:
	return players.values().filter(func(p): return not p.dead)


## Movimiento con terreno: los escalones más altos solo se suben saltando; se puede bajar siempre.
func _move_player(p: Player, delta: float) -> void:
	var before := p.position
	p.tick(delta)
	_keep_on_land(p)
	var after := p.position
	if not _can_stand(p, after):
		# probar deslizar por cada eje contra el acantilado
		p.position = Vector2(after.x, before.y)
		if not _can_stand(p, p.position):
			p.position = Vector2(before.x, after.y)
			if not _can_stand(p, p.position):
				p.position = before
	p.tick_vertical(delta, terrain.height_at(p.position))


func _can_stand(p: Player, pos: Vector2) -> bool:
	return terrain.height_at(pos) <= p.z + 0.05


## Caídos: un compañero vivo cerca durante REVIVE_TIME los levanta con media vida.
func _revives(delta: float) -> void:
	for p in players.values():
		if not p.dead:
			continue
		var helped := _alive().any(func(o): return o.position.distance_to(p.position) < REVIVE_RADIUS)
		p.revive = clampf(p.revive + (delta if helped else -delta) / REVIVE_TIME, 0.0, 1.0)
		if p.revive >= 1.0:
			p.revive_now()
			_banner("¡%s volvió a la pelea!" % p.player_name)


func _spawn(delta: float) -> void:
	var hp_coop := 1.0 + EXTRA_SPAWN_PER_PLAYER * (players.size() - 1)
	for b in STAGE.bosses:
		if time >= b.time and not _bosses_spawned.has(b):
			_bosses_spawned[b] = true
			enemies.spawn(b.enemy, _spawn_point(), hp_coop)
			_banner("¡Apareció %s!" % b.enemy.label())
	if survival and time >= _next_milestone:
		_milestone(hp_coop)
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
	var count := int((wave.batch + int(extra / 120.0)) * hp_coop)
	for k in count:
		enemies.spawn(wave.enemies.pick_random(), _spawn_point(), hp_mult)


## Hito de Supervivencia: jefe al azar más fuerte cada vez, y cofre al derrotarlo.
func _milestone(hp_coop: float) -> void:
	_next_milestone += MILESTONE
	var boss: EnemyData = STAGE.bosses.pick_random().enemy
	enemies.spawn(boss, _spawn_point(), (1.0 + time / 300.0) * hp_coop)
	_banner("¡Hito %d:00! Aparece %s" % [int(time / 60), boss.label()])


func _spawn_point() -> Vector2:
	var alive := _alive()
	var center: Vector2 = alive.pick_random().position if not alive.is_empty() else me.position
	var p := center + Vector2.RIGHT.rotated(randf() * TAU) * SPAWN_RADIUS
	if STAGE.water_from_x != INF:
		p.x = minf(p.x, (STAGE.water_from_x - 1.0) * PaperView.PX)
	return p


## El mar es el borde del mapa.
func _keep_on_land(node: Node2D) -> void:
	if STAGE.water_from_x != INF:
		node.position.x = minf(node.position.x, (STAGE.water_from_x - 1.0) * PaperView.PX)


## XP compartida: todos suben de nivel juntos.
func _on_xp(amount: int) -> void:
	for p in players.values():
		p.add_xp(amount)
		p.add_special(amount * SPECIAL_PER_XP)


func _on_enemy_killed(at: Vector2, data: EnemyData) -> void:
	kills += 1
	hud.kills = kills
	for p in players.values():
		p.add_special(SPECIAL_PER_KILL)
	gems.drop(at, data.xp)
	if data.boss:
		hazards.drop_chest(at)
		_banner("¡%s derrotado! Soltó un cofre" % data.label())


## Level up: el host arma las opciones de cada jugador; a los remotos se las manda.
func _offer_level_up(p: Player) -> void:
	if p == me:
		level_up.enqueue()
		return
	var opts: Array = arsenals[p.peer_id].level_up_options()
	if opts.is_empty():
		opts = [{}]
	if not _pending_options.has(p.peer_id):
		_pending_options[p.peer_id] = []
	_pending_options[p.peer_id].append(opts)
	Net.h_event.rpc_id(p.peer_id, "cartas", {"opciones": opts.map(func(o): return Arsenal.option_to_wire(o))})


## Cofre de jefe: 1 a 3 mejoras gratis para quien lo abre.
func _on_chest(p: Player) -> void:
	var n: int = [1, 1, 2, 3].pick_random()
	_banner("¡%s abrió un cofre! %d mejora%s" % [p.player_name, n, "s" if n > 1 else ""])
	for k in n:
		_offer_level_up(p)


## Las piedras no aparecen arriba de acantilados ni en el mar.
func _can_place_stone(p: Vector2) -> bool:
	if STAGE.water_from_x != INF and p.x > (STAGE.water_from_x - 3.0) * PaperView.PX:
		return false
	return terrain.height_at(p) == 0.0


func _on_stone(at: Vector2, reward: Dictionary, who: int) -> void:
	var p: Player = _alive()[who] if who >= 0 and who < _alive().size() else me
	var before := p.stats.max_hp
	p.stats.add_bonus(reward["stat"], reward["value"])
	p.hp += p.stats.max_hp - before
	_banner("¡%s: %s! %s" % [p.player_name, reward["name"], reward["text"]])
	_fx(at, 90.0, reward["color"])


## Especial (R): explosión grande alrededor del jugador; la potencia sube con la etapa.
func _fire_special(p: Player) -> void:
	if not p.special_ready() or p.dead:
		return
	p.special = 0.0
	var radius := SPECIAL_RADIUS * (1.0 + 0.25 * p.stage) * p.stats.area
	var damage := SPECIAL_DAMAGE * (1.0 + p.stage) * p.stats.might
	for i in enemies.in_circle(p.position, radius):
		enemies.hit(i, damage, p.position, 260.0)
	_fx(p.position, radius, p.character.special_color)
	p.play_once("ataque")
	_banner("¡%s!" % p.special_name())


## Digievolución: onda que limpia la pantalla y atrae toda la XP (PRD 5.2).
func _on_digivolved(p: Player, from_species: String, to_species: String) -> void:
	_banner("¡%s digievoluciona a %s!" % [from_species, to_species])
	_fx(p.position, SHOCKWAVE_RADIUS, Color(1, 1, 0.75))
	for i in enemies.in_circle(p.position, SHOCKWAVE_RADIUS):
		enemies.hit(i, SHOCKWAVE_DAMAGE, p.position, 200.0)
	gems.pull_all()


func _boss_bars() -> Array:
	var out := []
	for i in enemies.count():
		var d := enemies.data_of(i)
		if d.boss:
			out.append([d.label(), enemies.hp[i] / enemies.max_hp[i]])
	return out


## [nombre, segundos que faltan] del próximo jefe; avisa fuerte a los 10 segundos.
func _next_boss() -> Array:
	var best: BossSpawn = null
	for b in STAGE.bosses:
		if not _bosses_spawned.has(b) and (best == null or b.time < best.time):
			best = b
	if best == null:
		return ["Hito sorpresa", _next_milestone - time] if survival else []
	var left := best.time - time
	if left <= 10.0 and not _bosses_warned.has(best):
		_bosses_warned[best] = true
		_banner("¡%s llega en 10 segundos!" % best.enemy.label())
	return [best.enemy.label(), left]


func _end(text: String) -> void:
	if survival:
		text = "¡Aguantaron %d:%02d!" % [int(time) / 60, int(time) % 60] if players.size() > 1 else "¡Aguantaste %d:%02d!" % [int(time) / 60, int(time) % 60]
	_show_end(text)
	if online:
		Net.h_event.rpc("fin", {"texto": text, "t": time, "k": kills})
	if autotest:
		_report()
		print("[autotest] FIN: %s" % text)
		get_tree().quit()


func _show_end(text: String) -> void:
	running = false
	hud.end_text = text
	hud.end_hint = "R: jugar de nuevo · Esc: menú" if is_host else "Esperando al host · Esc: menú"
	me.play_once("victoria" if not text.begins_with("GAME") else "golpe")
	_submit_run(text != "GAME OVER" and not survival)


## Sube la run al ranking de Supabase (una vez por run y por jugador).
func _submit_run(won: bool) -> void:
	if _submitted or autotest:
		return
	_submitted = true
	Net.submit_run({"name": me.player_name, "character": me.character.id, "stage": "file_island",
		"mode": Session.mode, "seconds": int(time), "kills": kills, "level": me.level,
		"won": won, "players": players.size()})


# --- efectos y carteles (se replican a los clientes) ------------------------------------------------

func _banner(text: String) -> void:
	hud.show_banner(text, 2.5)
	if online and is_host:
		Net.h_event.rpc("cartel", {"texto": text})


func _fx(at: Vector2, radius_px: float, color: Color) -> void:
	view.burst(at, radius_px, color)
	if online and is_host:
		Net.h_event.rpc("fx", {"p": at, "r": radius_px, "c": color})


# --- red -------------------------------------------------------------------------------------------

func _on_client_state(peer_id: int, state: Dictionary) -> void:
	if is_host and players.has(peer_id):
		players[peer_id].set_remote(state)


func _on_client_action(peer_id: int, kind: String, value: int) -> void:
	if not is_host or not players.has(peer_id):
		return
	match kind:
		"especial":
			_fire_special(players[peer_id])
		"carta":
			var queue: Array = _pending_options.get(peer_id, [])
			if queue.is_empty():
				return
			var opts: Array = queue.pop_front()
			if value >= 0 and value < opts.size():
				arsenals[peer_id].apply(opts[value])


func _on_net_event(kind: String, data: Dictionary) -> void:
	match kind:
		"cartel":
			hud.show_banner(data["texto"], 2.5)
		"fx":
			view.burst(data["p"], data["r"], data["c"])
		"cartas":
			level_up.enqueue_options(data["opciones"].map(func(w): return Arsenal.option_from_wire(w)))
		"fin":
			time = data["t"]
			kills = data["k"]
			hud.time = time
			hud.kills = kills
			_show_end(data["texto"])
		"salio":
			var peer_id: int = data["peer"]
			if players.has(peer_id):
				_banner("%s se desconectó" % players[peer_id].player_name)
				players[peer_id].queue_free()
				arsenals[peer_id].queue_free()
				players.erase(peer_id)
				arsenals.erase(peer_id)
		"host_salio":
			running = false
			hud.end_text = "Se desconectó el host"
			hud.end_hint = "Esc: menú"


## Estado del mundo para los clientes.
func _snapshot() -> Dictionary:
	var flashes := PackedByteArray()
	var turns := PackedByteArray()
	var kinds := PackedByteArray()
	for i in enemies.count():
		flashes.append(1 if enemies.flash[i] > 0.0 and fmod(enemies.flash[i], 0.16) > 0.08 else 0)
		turns.append(int((enemies.turn[i] + 1.0) * 127.0))
		kinds.append(enemies.kind[i])
	var items := {}
	for peer_id in arsenals:
		items[peer_id] = arsenals[peer_id].items_to_wire()
	return {
		"t": time, "k": kills,
		"pl": players.values().map(func(p): return p.snapshot()),
		"it": items,
		"et": enemies.type_table(), "ek": kinds, "ep": enemies.pos, "ef": flashes, "eu": turns, "ea": enemies.anim_time,
		"pp": projectiles.pos, "pr": projectiles.radius, "pc": projectiles.color,
		"gp": gems.pos, "gv": gems.value,
		"wp": hazards.warn_pos, "wr": hazards.warn_radius, "wl": hazards.warn_left, "wt": hazards.warn_total,
		"sp": hazards.shot_pos, "ch": hazards.chests,
		"stp": stones.pos, "stc": stones.charge, "str": stones.reward_index,
		"bb": hud.bosses, "nb": hud.next_boss,
	}


func _on_snapshot(s: Dictionary) -> void:
	if is_host:
		return
	time = s["t"]
	kills = s["k"]
	hud.time = time
	hud.kills = kills
	for ps in s["pl"]:
		if players.has(ps[0]):
			players[ps[0]].apply_snapshot(ps, players[ps[0]] == me)
	if s["it"].has(me.peer_id):
		my_arsenal.items_from_wire(s["it"][me.peer_id])
	enemies.apply_snapshot(s["et"], s["ek"], s["ep"], s["ef"], s["eu"], s["ea"])
	projectiles.pos = s["pp"]
	projectiles.radius = s["pr"]
	projectiles.color = s["pc"]
	gems.pos = s["gp"]
	gems.value = s["gv"]
	hazards.warn_pos = s["wp"]
	hazards.warn_radius = s["wr"]
	hazards.warn_left = s["wl"]
	hazards.warn_total = s["wt"]
	hazards.shot_pos = s["sp"]
	hazards.chests = s["ch"]
	stones.pos = s["stp"]
	stones.charge = s["stc"]
	stones.reward_index = s["str"]
	hud.bosses = s["bb"]
	hud.next_boss = s["nb"]


# --- pruebas -----------------------------------------------------------------------------------------

## Bot simple: se aleja de los enemigos cercanos, salta los golpes al piso, usa el especial
## si está rodeado y si no hay peligro va hacia las gemas.
func _bot_direction() -> Vector2:
	for k in hazards.warn_pos.size():
		if me.position.distance_to(hazards.warn_pos[k]) < hazards.warn_radius[k] + 10.0 and hazards.warn_left[k] < 0.3:
			me.jump()
	if me.special_ready() and enemies.in_circle(me.position, 120.0).size() > 15:
		_fire_special(me)
	var flee := Vector2.ZERO
	for i in enemies.in_circle(me.position, 60.0):
		var away := me.position - enemies.pos[i]
		flee += away / maxf(away.length_squared(), 1.0)
	if flee != Vector2.ZERO:
		return (flee.normalized() + flee.normalized().orthogonal() * 0.6).normalized()
	var best := -1
	for i in gems.pos.size():
		if best < 0 or me.position.distance_squared_to(gems.pos[i]) < me.position.distance_squared_to(gems.pos[best]):
			best = i
	if best >= 0:
		return (gems.pos[best] - me.position).normalized()
	return Vector2.ZERO


## Prueba automática: `godot --headless --fixed-fps 60 --quit-after 60000 res://scenes/main.tscn -- --autotest`
func _report() -> void:
	print("[autotest] %02d:%02d nv %d %s hp %d/%d | enemigos %d gemas %d | kills %d | %s" % [
		int(time / 60), int(time) % 60, me.level, me.species(), me.hp, me.stats.max_hp,
		enemies.count(), gems.pos.size(), kills,
		", ".join(my_arsenal.weapons.keys().map(func(w): return "%s %d" % [w.display_name, my_arsenal.weapons[w]]))])
