class_name CharacterData
extends Resource
## Digimon jugable: su línea evolutiva y stats base (PRD 5).

@export var id := ""
@export var display_name := ""
## Especie de cada etapa, en orden (In-Training -> Rookie -> Champion ...). Nombres de assets/sprites/digimon/.
@export var line: PackedStringArray = []
## Nivel en el que se pasa a la etapa siguiente: evolve_levels[i] lleva de line[i] a line[i + 1].
@export var evolve_levels: PackedInt32Array = []
@export var starting_weapon: WeaponData
@export var max_hp := 100.0
@export var speed := 70.0
## Nombre del ataque especial (tecla R) en cada etapa.
@export var special_names: PackedStringArray = []
@export var special_color := Color(1.0, 0.6, 0.2)
@export_multiline var description := ""
