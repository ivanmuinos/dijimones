class_name Projectiles
extends Node2D
## Proyectiles como datos en arrays (PRD 8.3), con pooling implícito por swap-remove.

const LIFETIME := 2.0
const HIT_COOLDOWN := 0.2

var enemies: EnemyField

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var damage := PackedFloat32Array()
var radius := PackedFloat32Array()
var pierce := PackedInt32Array()
var life := PackedFloat32Array()
var hit_cd := PackedFloat32Array()
var color := PackedColorArray()


func fire(from: Vector2, velocity: Vector2, dmg: float, r: float, pierce_count: int, c: Color) -> void:
	pos.append(from)
	vel.append(velocity)
	damage.append(dmg)
	radius.append(r)
	pierce.append(pierce_count)
	life.append(LIFETIME)
	hit_cd.append(0.0)
	color.append(c)


func tick(delta: float) -> void:
	var i := pos.size() - 1
	while i >= 0:
		pos[i] += vel[i] * delta
		life[i] -= delta
		hit_cd[i] = maxf(hit_cd[i] - delta, 0.0)
		if hit_cd[i] <= 0.0:
			var hits := enemies.in_circle(pos[i], radius[i])
			if not hits.is_empty():
				enemies.hit(hits[0], damage[i], pos[i] - vel[i].normalized() * 4.0)
				pierce[i] -= 1
				hit_cd[i] = HIT_COOLDOWN
		if life[i] <= 0.0 or pierce[i] <= 0:
			_remove(i)
		i -= 1
	queue_redraw()


func _remove(i: int) -> void:
	# los Packed*Array se copian al meterlos en una lista: hay que tocar cada uno directamente
	var last := pos.size() - 1
	pos[i] = pos[last]
	vel[i] = vel[last]
	damage[i] = damage[last]
	radius[i] = radius[last]
	pierce[i] = pierce[last]
	life[i] = life[last]
	hit_cd[i] = hit_cd[last]
	color[i] = color[last]
	pos.resize(last)
	vel.resize(last)
	damage.resize(last)
	radius.resize(last)
	pierce.resize(last)
	life.resize(last)
	hit_cd.resize(last)
	color.resize(last)


func _draw() -> void:
	for i in pos.size():
		draw_circle(pos[i], radius[i] + 1.0, Color(0.1, 0.05, 0.05))
		draw_circle(pos[i], radius[i], color[i])
		draw_circle(pos[i] - Vector2(1, 1), radius[i] * 0.45, color[i].lightened(0.6))
