class_name Stats
extends RefCounted
## Stats del jugador: base del personaje + bonus por etapa evolutiva + chips pasivos (PRD 5 y 6).

var max_hp := 100.0
var speed := 70.0
var might := 1.0
var area := 1.0
var cooldown := 1.0
var magnet := 60.0
var armor := 0.0
var recovery := 0.0

var _base_hp := 100.0
var _base_speed := 70.0
var _stage := 0
var _passives := {}  # PassiveData -> nivel


func setup(character: CharacterData) -> void:
	_base_hp = character.max_hp
	_base_speed = character.speed
	recompute()


func set_stage(stage: int) -> void:
	_stage = stage
	recompute()


func set_passive(passive: PassiveData, level: int) -> void:
	_passives[passive] = level
	recompute()


## Cada etapa evolutiva: +40 % vida, +15 % daño, +5 % velocidad.
func recompute() -> void:
	max_hp = _base_hp * (1.0 + 0.4 * _stage)
	speed = _base_speed * (1.0 + 0.05 * _stage)
	might = 1.0 + 0.15 * _stage
	area = 1.0
	cooldown = 1.0
	magnet = 60.0
	armor = 0.0
	recovery = 0.0
	for passive in _passives:
		var bonus: float = passive.per_level * _passives[passive]
		match passive.stat:
			"might": might += bonus
			"speed": speed *= 1.0 + bonus
			"area": area += bonus
			"cooldown": cooldown = maxf(cooldown + bonus, 0.4)
			"max_hp": max_hp += bonus
			"magnet": magnet *= 1.0 + bonus
			"armor": armor += bonus
			"recovery": recovery += bonus
