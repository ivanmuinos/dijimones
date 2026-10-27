class_name HolyStones
extends RefCounted
## Piedras Sagradas (santuarios, idea de PokeBonk/Megabonk con lore de Adventure 02): aparecen por el mapa;
## si te quedás cerca CHARGE_TIME segundos se activan y dan un bonus permanente para la run.

signal activated(pos: Vector2, reward: Dictionary, player_index: int)

const ACTIVE := 3
const RADIUS := 44.0  # px: zona de carga alrededor de la piedra
const CHARGE_TIME := 4.0
const SPAWN_DIST := Vector2(420.0, 900.0)  # px desde el jugador
const REWARDS := [
	{"name": "Piedra del Valor", "text": "+15 % de daño", "stat": "might", "value": 0.15, "color": Color(1, 0.55, 0.2)},
	{"name": "Piedra de la Amistad", "text": "+30 de vida máxima", "stat": "max_hp", "value": 30.0, "color": Color(0.4, 0.75, 1)},
	{"name": "Piedra del Conocimiento", "text": "+10 % de área", "stat": "area", "value": 0.1, "color": Color(0.85, 0.75, 0.3)},
	{"name": "Piedra de la Sinceridad", "text": "+12 % de velocidad", "stat": "speed", "value": 0.12, "color": Color(0.45, 0.85, 0.4)},
	{"name": "Piedra de la Esperanza", "text": "+0.5 vida por segundo", "stat": "recovery", "value": 0.5, "color": Color(1, 0.95, 0.5)},
	{"name": "Piedra de la Luz", "text": "-8 % de recarga", "stat": "cooldown", "value": -0.08, "color": Color(1, 0.75, 0.85)},
	{"name": "Piedra del Amor", "text": "+40 % de imán", "stat": "magnet", "value": 0.4, "color": Color(1, 0.45, 0.6)},
]

var pos := PackedVector2Array()
var charge := PackedFloat32Array()
var reward_index := PackedInt32Array()
var _rng := RandomNumberGenerator.new()


## `targets`: posiciones de los jugadores vivos. Carga cualquiera que esté cerca; el premio es para él.
func tick(delta: float, targets: PackedVector2Array, can_place: Callable) -> void:
	if targets.is_empty():
		return
	var player_pos := targets[0]
	while pos.size() < ACTIVE:
		_place(player_pos, can_place)
	var i := pos.size() - 1
	while i >= 0:
		var who := -1
		var d := INF
		for k in targets.size():
			var dk := targets[k].distance_to(pos[i])
			if dk < d:
				d = dk
				who = k
		if d < RADIUS:
			charge[i] += delta / CHARGE_TIME
		else:
			charge[i] = maxf(charge[i] - delta / (CHARGE_TIME * 2.0), 0.0)
		if charge[i] >= 1.0:
			activated.emit(pos[i], REWARDS[reward_index[i]], who)
			_remove(i)
		elif d > SPAWN_DIST.y * 1.8:
			_remove(i)  # quedó muy lejos: aparece otra más cerca
		i -= 1


func color_of(i: int) -> Color:
	return REWARDS[reward_index[i]]["color"]


func _place(player_pos: Vector2, can_place: Callable) -> void:
	for attempt in 12:
		var p := player_pos + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(SPAWN_DIST.x, SPAWN_DIST.y)
		if can_place.call(p):
			pos.append(p)
			charge.append(0.0)
			reward_index.append(_rng.randi() % REWARDS.size())
			return
	pos.append(player_pos + Vector2(SPAWN_DIST.x, 0))
	charge.append(0.0)
	reward_index.append(_rng.randi() % REWARDS.size())


func _remove(i: int) -> void:
	pos.remove_at(i)
	charge.remove_at(i)
	reward_index.remove_at(i)
