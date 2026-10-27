class_name WeaponData
extends Resource
## Arma automática (PRD 6). El patrón de ataque lo define `kind`.

enum Kind { PROJECTILE_NEAREST, AURA }

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var kind := Kind.PROJECTILE_NEAREST
@export var damage := 10.0
@export var cooldown := 1.0
@export var amount := 1
@export var projectile_speed := 220.0
@export var pierce := 1
@export var area := 1.0
@export var color := Color(1.0, 0.55, 0.15)
@export var max_level := 8


## Mejoras por nivel, iguales para todas las armas por ahora: +25 % daño por nivel,
## +1 proyectil en niveles 3 y 6, -15 % cooldown en niveles 4 y 7.
func damage_at(level: int) -> float:
	return damage * (1.0 + 0.25 * (level - 1))


func amount_at(level: int) -> int:
	return amount + int(level >= 3) + int(level >= 6)


func cooldown_at(level: int) -> float:
	return cooldown * pow(0.85, int(level >= 4) + int(level >= 7))
