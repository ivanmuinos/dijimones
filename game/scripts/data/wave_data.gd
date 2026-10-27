class_name WaveData
extends Resource
## Tramo de tiempo de un mapa: qué enemigos aparecen y con qué ritmo.

@export var start := 0.0
@export var end := 60.0
@export var enemies: Array[EnemyData] = []
## Segundos entre tandas.
@export var interval := 1.0
## Enemigos por tanda.
@export var batch := 2
