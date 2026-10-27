class_name EnemyData
extends Resource
## Enemigo (PRD 6). `species` es la carpeta de sprites en assets/sprites/digimon/.

@export var species := ""
@export var hp := 10.0
@export var speed := 40.0
## Daño por segundo mientras toca al jugador.
@export var damage := 10.0
@export var xp := 1
@export var scale := 1.0
@export var boss := false
@export var display_name := ""

@export_group("Ataques (jefes)")
## CHASE: solo persigue. CHARGER: se frena, avisa y embiste. SLAM: golpe al piso con aviso (se esquiva saltando).
## SHOOTER: ráfaga de proyectiles en círculo. ALL: alterna los tres.
enum Behavior { CHASE, CHARGER, SLAM, SHOOTER, ALL }
@export var behavior := Behavior.CHASE
@export var attack_every := 3.0
@export var attack_damage := 20.0
## Radio del golpe al piso (px).
@export var attack_radius := 80.0
@export var shots := 10
@export var shot_speed := 110.0


func label() -> String:
	return display_name if display_name != "" else species
