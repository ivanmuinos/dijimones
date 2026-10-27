class_name XpGems
extends Node2D
## Fragmentos de Data (XP) que sueltan los enemigos; el imán los atrae al jugador.

signal collected(amount: int)

const MAX_GEMS := 400
const PICKUP_RADIUS := 10.0
const PULL_SPEED := 260.0

var pos := PackedVector2Array()
var value := PackedInt32Array()
var pulled := PackedByteArray()


func drop(at: Vector2, amount: int) -> void:
	# con demasiadas gemas, se suman a la más cercana en vez de crear otra (PRD 8.3)
	if pos.size() >= MAX_GEMS:
		var best := 0
		for i in pos.size():
			if at.distance_squared_to(pos[i]) < at.distance_squared_to(pos[best]):
				best = i
		value[best] += amount
		return
	pos.append(at)
	value.append(amount)
	pulled.append(0)


## Cada gema va hacia el jugador más cercano que la tenga en su imán; la XP es compartida.
func tick(delta: float, targets: PackedVector2Array, magnets: PackedFloat32Array) -> void:
	var i := pos.size() - 1
	while i >= 0:
		var best := -1
		var d := INF
		for k in targets.size():
			var dk := targets[k].distance_to(pos[i])
			if dk < d:
				d = dk
				best = k
		if best < 0:
			i -= 1
			continue
		if d < magnets[best]:
			pulled[i] = 1
		if pulled[i]:
			pos[i] = pos[i].move_toward(targets[best], PULL_SPEED * delta)
		if d < PICKUP_RADIUS:
			collected.emit(value[i])
			var last := pos.size() - 1
			pos[i] = pos[last]
			value[i] = value[last]
			pulled[i] = pulled[last]
			pos.resize(last)
			value.resize(last)
			pulled.resize(last)
		i -= 1
	queue_redraw()


## Atrae todas las gemas (al digievolucionar).
func pull_all() -> void:
	for i in pulled.size():
		pulled[i] = 1


func _draw() -> void:
	for i in pos.size():
		var c := Color(0.35, 0.85, 1.0)
		if value[i] >= 10:
			c = Color(1.0, 0.3, 0.4)
		elif value[i] >= 3:
			c = Color(0.4, 1.0, 0.5)
		var p := pos[i]
		var pts := PackedVector2Array([p + Vector2(0, -4), p + Vector2(3, 0), p + Vector2(0, 4), p + Vector2(-3, 0)])
		draw_colored_polygon(pts, c)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.05, 0.1, 0.15), 1.0)
