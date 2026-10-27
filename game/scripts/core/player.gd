class_name Player
extends Node2D
## El Digimon del jugador: movimiento, vida, nivel y digievolución por nivel (PRD 5.2).

signal leveled_up(level: int)
signal digivolved(from_species: String, to_species: String)
signal died

var character: CharacterData
var stats := Stats.new()
var hp := 100.0
var level := 1
var xp := 0
var stage := 0
var invulnerable := 0.0
var velocity := Vector2.ZERO
var dead := false
## Altura absoluta (m) y velocidad vertical: el piso lo da Terrain.
var z := 0.0
var vz := 0.0
var floor_height := 0.0
## Carga del especial (0..1).
var special := 0.0
const HIT_INVULNERABILITY := 0.5
const JUMP_SPEED := 8.0  # m/s: llega a ~1.07 m, alcanza para subir un escalón
const GRAVITY := 30.0
## Por encima de esta altura sobre el piso, los enemigos no te tocan (saltás por arriba).
const AIR_SAFE_HEIGHT := 0.45

var autopilot := Vector2.ZERO  # pruebas automáticas: dirección que decide main.gd
var use_autopilot := false

var _sprite := AnimatedSprite2D.new()
var _hurt_flash := 0.0
var _locked_anim := ""  # animación que no se interrumpe (ataque/golpe/victoria)


func setup(data: CharacterData) -> void:
	character = data
	stats.setup(data)
	hp = stats.max_hp
	_sprite.centered = false
	add_child(_sprite)
	_sprite.animation_finished.connect(func(): _locked_anim = "")
	_load_species()


func species() -> String:
	return character.line[stage]


func radius() -> float:
	return DigimonDB.species(species())["radius"]


func anim_name() -> String:
	return _sprite.animation


func anim_frame() -> int:
	return _sprite.frame


func facing_left() -> bool:
	return _sprite.flip_h


func hurt_flash() -> bool:
	return _hurt_flash > 0.0


func airborne() -> bool:
	return z - floor_height > AIR_SAFE_HEIGHT


func grounded() -> bool:
	return z <= floor_height + 0.01


func jump() -> void:
	if grounded() and not dead:
		vz = JUMP_SPEED


## Física vertical: gravedad hasta el piso actual.
func tick_vertical(delta: float, floor_h: float) -> void:
	floor_height = floor_h
	vz -= GRAVITY * delta
	z += vz * delta
	if z <= floor_height:
		z = floor_height
		vz = 0.0


func xp_to_next() -> int:
	return 5 + 8 * (level - 1)


func tick(delta: float) -> void:
	if dead:
		return
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if use_autopilot:
		input = autopilot
	elif input == Vector2.ZERO:
		input = Vector2(
			int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)),
			int(Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_W))).normalized()
	velocity = input * stats.speed
	position += velocity * delta
	if absf(input.x) > 0.1:
		_sprite.flip_h = input.x < 0.0
		_sprite.offset.x = -_anchor().x if not _sprite.flip_h else _anchor().x - _size()
	invulnerable = maxf(invulnerable - delta, 0.0)
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	hp = minf(hp + stats.recovery * delta, stats.max_hp)
	_sprite.modulate = Color(3, 1, 1) if _hurt_flash > 0.0 else Color.WHITE
	if _locked_anim == "":
		_play("correr" if velocity != Vector2.ZERO else "idle")
	queue_redraw()


## Golpe por contacto: `dps` es el daño por segundo del enemigo; después de cada golpe hay
## HIT_INVULNERABILITY de invulnerabilidad, así el daño no se multiplica con la cantidad de enemigos.
## La armadura reduce un 5 % por punto (máx. 50 %).
func take_damage(dps: float) -> void:
	if dead or invulnerable > 0.0 or dps <= 0.0:
		return
	hp -= dps * HIT_INVULNERABILITY * (1.0 - minf(stats.armor * 0.05, 0.5))
	invulnerable = HIT_INVULNERABILITY
	_hurt_flash = 0.1
	if hp <= 0.0:
		hp = 0.0
		dead = true
		died.emit()


## Golpe directo (golpe al piso, proyectil de jefe), con la misma invulnerabilidad corta.
func take_hit(amount: float) -> void:
	if dead or invulnerable > 0.0:
		return
	hp -= amount * (1.0 - minf(stats.armor * 0.05, 0.5))
	invulnerable = HIT_INVULNERABILITY
	_hurt_flash = 0.15
	if hp <= 0.0:
		hp = 0.0
		dead = true
		died.emit()


## Especial (tecla R): se carga con XP y kills.
func add_special(amount: float) -> void:
	special = minf(special + amount, 1.0)


func special_ready() -> bool:
	return special >= 1.0


func special_name() -> String:
	if stage < character.special_names.size():
		return character.special_names[stage]
	return "Especial"


## Suma XP; puede subir varios niveles de una. Devuelve cuántos subió.
func add_xp(amount: int) -> int:
	xp += amount
	var ups := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		ups += 1
		leveled_up.emit(level)
		_check_digivolution()
	return ups


func play_once(anim: String) -> void:
	if _sprite.sprite_frames.has_animation(anim):
		_locked_anim = anim
		_sprite.play(anim)


func _check_digivolution() -> void:
	if stage >= character.evolve_levels.size() or level < character.evolve_levels[stage]:
		return
	var from := species()
	stage += 1
	stats.set_stage(stage)
	hp = stats.max_hp
	_load_species()
	digivolved.emit(from, species())


func _load_species() -> void:
	_sprite.sprite_frames = DigimonDB.sprite_frames(species())
	_sprite.offset = -_anchor()
	_sprite.flip_h = false
	_locked_anim = ""
	_play("idle")


func _play(anim: String) -> void:
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _anchor() -> Vector2:
	return DigimonDB.species(species())["anchor"]


func _size() -> int:
	return DigimonDB.species(species())["size"]


func _draw() -> void:
	# barra de vida debajo de los pies
	var w := 24.0
	draw_rect(Rect2(-w / 2, 3, w, 3), Color(0.1, 0.05, 0.05))
	draw_rect(Rect2(-w / 2, 3, w * hp / stats.max_hp, 3), Color(0.9, 0.2, 0.2))
