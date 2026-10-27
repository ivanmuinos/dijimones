class_name Hazards
extends RefCounted
## Cosas peligrosas o premios que no son enemigos: avisos de golpe al piso (se esquivan saltando),
## proyectiles de jefes y cofres que sueltan los jefes al morir.

signal chest_opened(player: Player)

const SHOT_RADIUS := 5.0
const SHOT_LIFE := 4.0
const CHEST_PICKUP := 18.0

# avisos: posición, radio, tiempo restante, duración total, daño
var warn_pos := PackedVector2Array()
var warn_radius := PackedFloat32Array()
var warn_left := PackedFloat32Array()
var warn_total := PackedFloat32Array()
var warn_damage := PackedFloat32Array()
## Golpes que se completaron este frame (para el efecto visual).
var slams_now: Array = []

var shot_pos := PackedVector2Array()
var shot_vel := PackedVector2Array()
var shot_damage := PackedFloat32Array()
var shot_life := PackedFloat32Array()

var chests := PackedVector2Array()


func slam(at: Vector2, radius: float, damage: float, delay: float) -> void:
	warn_pos.append(at)
	warn_radius.append(radius)
	warn_left.append(delay)
	warn_total.append(delay)
	warn_damage.append(damage)


func shot(at: Vector2, velocity: Vector2, damage: float) -> void:
	shot_pos.append(at)
	shot_vel.append(velocity)
	shot_damage.append(damage)
	shot_life.append(SHOT_LIFE)


func drop_chest(at: Vector2) -> void:
	chests.append(at)


func tick(delta: float, players: Array) -> void:
	slams_now.clear()
	var i := warn_pos.size() - 1
	while i >= 0:
		warn_left[i] -= delta
		if warn_left[i] <= 0.0:
			for player in players:
				if player.position.distance_to(warn_pos[i]) < warn_radius[i] + player.radius() and not player.airborne():
					player.take_hit(warn_damage[i])
			slams_now.append([warn_pos[i], warn_radius[i]])
			_remove_warn(i)
		i -= 1
	i = shot_pos.size() - 1
	while i >= 0:
		shot_pos[i] += shot_vel[i] * delta
		shot_life[i] -= delta
		var hit := false
		for player in players:
			if player.position.distance_to(shot_pos[i]) < SHOT_RADIUS + player.radius() and not player.airborne():
				player.take_hit(shot_damage[i])
				hit = true
				break
		if hit or shot_life[i] <= 0.0:
			_remove_shot(i)
		i -= 1
	i = chests.size() - 1
	while i >= 0:
		for player in players:
			if player.position.distance_to(chests[i]) < CHEST_PICKUP:
				chests.remove_at(i)
				chest_opened.emit(player)
				break
		i -= 1


func _remove_warn(i: int) -> void:
	warn_pos.remove_at(i)
	warn_radius.remove_at(i)
	warn_left.remove_at(i)
	warn_total.remove_at(i)
	warn_damage.remove_at(i)


func _remove_shot(i: int) -> void:
	var last := shot_pos.size() - 1
	shot_pos[i] = shot_pos[last]
	shot_vel[i] = shot_vel[last]
	shot_damage[i] = shot_damage[last]
	shot_life[i] = shot_life[last]
	shot_pos.resize(last)
	shot_vel.resize(last)
	shot_damage.resize(last)
	shot_life.resize(last)
