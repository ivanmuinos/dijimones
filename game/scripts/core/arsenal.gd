class_name Arsenal
extends Node2D
## Armas y chips del jugador: dispara las armas y arma las opciones de level up (PRD 4 y 6).

const MAX_WEAPONS := 6
const MAX_PASSIVES := 6
const WEAPON_POOL := [
	preload("res://data/weapons/pepper_breath.tres"),
	preload("res://data/weapons/boom_bubble.tres"),
	preload("res://data/weapons/fire_wall.tres"),
	preload("res://data/weapons/blue_blaster.tres"),
]
const PASSIVE_POOL := [
	preload("res://data/passives/power_chip.tres"),
	preload("res://data/passives/speed_chip.tres"),
	preload("res://data/passives/range_chip.tres"),
	preload("res://data/passives/cooldown_chip.tres"),
	preload("res://data/passives/hp_chip.tres"),
	preload("res://data/passives/magnet_chip.tres"),
	preload("res://data/passives/armor_chip.tres"),
	preload("res://data/passives/recovery_chip.tres"),
]
const AURA_BASE_RADIUS := 34.0

var player: Player
var enemies: EnemyField
var projectiles: Projectiles

var weapons := {}  # WeaponData -> nivel
var passives := {}  # PassiveData -> nivel
var _timers := {}  # WeaponData -> segundos hasta el próximo disparo
var _aura_pulse := 0.0


func add_weapon(w: WeaponData) -> void:
	weapons[w] = weapons.get(w, 0) + 1
	_timers[w] = 0.0


func add_passive(p: PassiveData) -> void:
	passives[p] = passives.get(p, 0) + 1
	player.stats.set_passive(p, passives[p])


## Hasta 3 opciones al azar entre armas nuevas/mejoras y chips nuevos/mejoras.
func level_up_options() -> Array:
	var pool := []
	for w in WEAPON_POOL:
		var lvl: int = weapons.get(w, 0)
		if (lvl == 0 and weapons.size() < MAX_WEAPONS) or (lvl > 0 and lvl < w.max_level):
			pool.append({"item": w, "level": lvl + 1})
	for p in PASSIVE_POOL:
		var lvl: int = passives.get(p, 0)
		if (lvl == 0 and passives.size() < MAX_PASSIVES) or (lvl > 0 and lvl < p.max_level):
			pool.append({"item": p, "level": lvl + 1})
	pool.shuffle()
	return pool.slice(0, 3)


func apply(option: Dictionary) -> void:
	if option.is_empty():
		player.hp = minf(player.hp + 30.0, player.stats.max_hp)
	elif option["item"] is WeaponData:
		add_weapon(option["item"])
	else:
		add_passive(option["item"])


func tick(delta: float) -> void:
	_aura_pulse = maxf(_aura_pulse - delta, 0.0)
	for w in weapons:
		_timers[w] -= delta
		if _timers[w] > 0.0:
			continue
		var lvl: int = weapons[w]
		_timers[w] = w.cooldown_at(lvl) * player.stats.cooldown
		match w.kind:
			WeaponData.Kind.PROJECTILE_NEAREST:
				_fire_nearest(w, lvl)
			WeaponData.Kind.AURA:
				_aura(w, lvl)
	queue_redraw()


func _fire_nearest(w: WeaponData, lvl: int) -> void:
	var origin := player.position + Vector2(0, -10)
	var target := enemies.nearest(origin, 320.0)
	if target < 0:
		return
	var dir := (enemies.pos[target] - origin).normalized()
	var n := w.amount_at(lvl)
	for k in n:
		var spread := (k - (n - 1) * 0.5) * 0.18
		projectiles.fire(origin, dir.rotated(spread) * w.projectile_speed, w.damage_at(lvl) * player.stats.might,
			3.0 * w.area * player.stats.area, w.pierce, w.color)
	player.play_once("ataque")


func _aura(w: WeaponData, lvl: int) -> void:
	var r := aura_radius(w, lvl)
	for i in enemies.in_circle(player.position, r):
		enemies.hit(i, w.damage_at(lvl) * player.stats.might, player.position, 20.0)
	_aura_pulse = 0.15


func aura_pulse() -> float:
	return _aura_pulse


func aura_radius(w: WeaponData, lvl := -1) -> float:
	if lvl < 0:
		lvl = weapons.get(w, 1)
	return AURA_BASE_RADIUS * w.area * player.stats.area * (1.0 + 0.08 * (lvl - 1))


func _draw() -> void:
	for w in weapons:
		if w.kind == WeaponData.Kind.AURA:
			var r := aura_radius(w, weapons[w])
			var c: Color = w.color
			c.a = 0.18 + _aura_pulse
			draw_circle(player.position, r, c)
			draw_arc(player.position, r, 0, TAU, 32, Color(c, 0.6), 1.0)
