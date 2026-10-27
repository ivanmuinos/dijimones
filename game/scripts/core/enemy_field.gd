class_name EnemyField
extends Node2D
## Todos los enemigos como datos en arrays y dibujados por un solo nodo (PRD 8.3):
## nada de un nodo por enemigo, para aguantar cientos en pantalla.

signal killed(pos: Vector2, data: EnemyData)
## Golpe al piso: Hazards lo avisa con un círculo y pega cuando se completa.
signal attack_slam(pos: Vector2, radius: float, damage: float, delay: float)
signal attack_shot(pos: Vector2, velocity: Vector2, damage: float)

const WINDUP := 0.6
const DASH_TIME := 0.55
const DASH_SPEED_MULT := 5.0

const MAX_ENEMIES := 500
const KNOCKBACK_DECAY := 8.0
const FLASH_TIME := 0.1

var player_radius := 8.0

var pos := PackedVector2Array()
var knock := PackedVector2Array()
var hp := PackedFloat32Array()
var anim_time := PackedFloat32Array()
var flash := PackedFloat32Array()
var facing_left := PackedByteArray()
## -1..1: escala x del recorte de papel (gira como una hoja al cambiar de dirección)
var turn := PackedFloat32Array()
var kind := PackedInt32Array()
var max_hp := PackedFloat32Array()
## IA de jefes: tiempo al próximo ataque, preparación (quieto, avisando), embestida en curso.
var ai_t := PackedFloat32Array()
var windup := PackedFloat32Array()
var dash_t := PackedFloat32Array()
var dash_dir := PackedVector2Array()
var ai_step := PackedInt32Array()

var _types: Array[EnemyData] = []
var _sprites: Array[Dictionary] = []
var _grid := SpatialHash.new(48.0)


func count() -> int:
	return pos.size()


func spawn(data: EnemyData, at: Vector2, hp_mult := 1.0) -> void:
	if count() >= MAX_ENEMIES and not data.boss:
		return
	pos.append(at)
	knock.append(Vector2.ZERO)
	hp.append(data.hp * hp_mult)
	anim_time.append(randf() * 2.0)
	flash.append(0.0)
	facing_left.append(0)
	turn.append(1.0)
	kind.append(_type_index(data))
	max_hp.append(data.hp * hp_mult)
	ai_t.append(data.attack_every)
	windup.append(0.0)
	dash_t.append(0.0)
	dash_dir.append(Vector2.ZERO)
	ai_step.append(0)


func data_of(i: int) -> EnemyData:
	return _types[kind[i]]


func radius_of(i: int) -> float:
	var t := kind[i]
	return _sprites[t]["radius"] * _types[t].scale


## Mueve a todos hacia el jugador, separa los que se pisan y devuelve el `damage` más alto
## entre los que lo están tocando (0 si ninguno).
func tick(delta: float, target: Vector2) -> float:
	var contact_damage := 0.0
	_grid.clear()
	for i in count():
		_grid.insert(i, pos[i])
	for i in count():
		var data := data_of(i)
		var to_target := target - pos[i]
		var dir := to_target.normalized()
		var step := dir * data.speed + knock[i]
		if data.behavior != EnemyData.Behavior.CHASE:
			step = _think(i, data, dir, step, delta)
		# separación: empuja lejos de los vecinos que se superponen
		var r := radius_of(i)
		for j in _grid.query(pos[i], r * 2.0):
			if j == i:
				continue
			var away := pos[i] - pos[j]
			var d := away.length()
			var min_d := r + radius_of(j)
			if d > 0.001 and d < min_d:
				step += away / d * (min_d - d) * 6.0
		pos[i] += step * delta
		knock[i] = knock[i].lerp(Vector2.ZERO, clampf(KNOCKBACK_DECAY * delta, 0.0, 1.0))
		anim_time[i] += delta
		flash[i] = maxf(flash[i] - delta, 0.0)
		if absf(dir.x) > 0.1:
			facing_left[i] = 1 if dir.x < 0.0 else 0
		turn[i] = move_toward(turn[i], -1.0 if facing_left[i] else 1.0, 7.0 * delta)
		if to_target.length() < r + player_radius:
			contact_damage = maxf(contact_damage, data.damage)
	queue_redraw()
	return contact_damage


## Ataques de jefes. Devuelve el desplazamiento de este frame.
func _think(i: int, data: EnemyData, dir: Vector2, step: Vector2, delta: float) -> Vector2:
	if dash_t[i] > 0.0:
		dash_t[i] -= delta
		return dash_dir[i] * data.speed * DASH_SPEED_MULT
	if windup[i] > 0.0:
		windup[i] -= delta
		if windup[i] <= 0.0:
			_release(i, data)
		return Vector2.ZERO  # quieto mientras avisa
	ai_t[i] -= delta
	if ai_t[i] <= 0.0:
		ai_t[i] = data.attack_every
		windup[i] = WINDUP
		dash_dir[i] = dir
		flash[i] = WINDUP  # brilla mientras prepara el ataque
		if _current_attack(i, data) == EnemyData.Behavior.SLAM:
			attack_slam.emit(pos[i], data.attack_radius * data.scale, data.attack_damage, WINDUP + 0.4)
	return step


func _current_attack(i: int, data: EnemyData) -> int:
	if data.behavior != EnemyData.Behavior.ALL:
		return data.behavior
	return [EnemyData.Behavior.CHARGER, EnemyData.Behavior.SLAM, EnemyData.Behavior.SHOOTER][ai_step[i] % 3]


func _release(i: int, data: EnemyData) -> void:
	match _current_attack(i, data):
		EnemyData.Behavior.CHARGER:
			dash_t[i] = DASH_TIME
		EnemyData.Behavior.SHOOTER:
			var offset := randf() * TAU
			for k in data.shots:
				var v := Vector2.RIGHT.rotated(offset + TAU * k / data.shots) * data.shot_speed
				attack_shot.emit(pos[i], v, data.attack_damage * 0.5)
	ai_step[i] += 1


func hit(i: int, amount: float, from: Vector2, knockback := 60.0) -> void:
	if hp[i] <= 0.0:
		return
	hp[i] -= amount
	flash[i] = FLASH_TIME
	if not data_of(i).boss:
		knock[i] += (pos[i] - from).normalized() * knockback


## Saca a los muertos (swap-remove) y avisa por cada uno. Llamar una vez por frame, después de los daños.
func remove_dead() -> void:
	var i := count() - 1
	while i >= 0:
		if hp[i] <= 0.0:
			killed.emit(pos[i], data_of(i))
			_remove(i)
		i -= 1


func nearest(to: Vector2, max_dist := INF) -> int:
	var best := -1
	var best_d := max_dist * max_dist
	for i in count():
		var d := to.distance_squared_to(pos[i])
		if d < best_d:
			best_d = d
			best = i
	return best


## Índices de enemigos cuyo radio toca el círculo dado.
func in_circle(center: Vector2, radius: float) -> Array:
	var out := []
	for i in _grid.query(center, radius + 40.0):
		if i < count() and center.distance_to(pos[i]) < radius + radius_of(i):
			out.append(i)
	return out


func _remove(i: int) -> void:
	var last := count() - 1
	if i != last:
		pos[i] = pos[last]
		knock[i] = knock[last]
		hp[i] = hp[last]
		anim_time[i] = anim_time[last]
		flash[i] = flash[last]
		facing_left[i] = facing_left[last]
		turn[i] = turn[last]
		kind[i] = kind[last]
		max_hp[i] = max_hp[last]
		ai_t[i] = ai_t[last]
		windup[i] = windup[last]
		dash_t[i] = dash_t[last]
		dash_dir[i] = dash_dir[last]
		ai_step[i] = ai_step[last]
	max_hp.resize(last)
	ai_t.resize(last)
	windup.resize(last)
	dash_t.resize(last)
	dash_dir.resize(last)
	ai_step.resize(last)
	pos.resize(last)
	knock.resize(last)
	hp.resize(last)
	anim_time.resize(last)
	flash.resize(last)
	facing_left.resize(last)
	turn.resize(last)
	kind.resize(last)


func _type_index(data: EnemyData) -> int:
	var idx := _types.find(data)
	if idx >= 0:
		return idx
	_types.append(data)
	_sprites.append(DigimonDB.species(data.species))
	return _types.size() - 1


func _draw() -> void:
	# los de más abajo se dibujan después (encima)
	var order := range(count())
	order.sort_custom(func(a, b): return pos[a].y < pos[b].y)
	for i in order:
		var sp: Dictionary = _sprites[kind[i]]
		var anim: Dictionary = sp["anims"].get("correr", sp["anims"].get("idle"))
		var size: int = sp["size"]
		var scale := _types[kind[i]].scale
		var frame := int(anim_time[i] * anim["fps"]) % int(anim["frames"])
		var src := Rect2(frame * size, 0, size, size)
		var anchor: Vector2 = sp["anchor"] * scale
		var dst := Rect2(pos[i] - anchor, Vector2(size, size) * scale)
		if facing_left[i]:
			dst.position.x = pos[i].x + anchor.x
			dst.size.x = -dst.size.x
		var mod := Color(3, 3, 3) if flash[i] > 0.0 else Color.WHITE
		draw_texture_rect_region(anim["texture"], dst, src, mod)
