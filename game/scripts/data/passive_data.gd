class_name PassiveData
extends Resource
## Chip pasivo: suma a un stat del jugador por nivel (PRD 6).

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
## Nombre del stat en Stats (might, speed, area, cooldown, max_hp, magnet, armor, recovery).
@export var stat := "might"
@export var per_level := 0.1
@export var max_level := 5
