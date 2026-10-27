class_name StageData
extends Resource
## Mapa: oleadas por minuto y jefes (PRD 6 y 7.3).

@export var display_name := ""
@export var duration := 900.0
@export var waves: Array[WaveData] = []
@export var bosses: Array[BossSpawn] = []

@export_group("Look (papel)")
@export var sky_color := Color(0.74, 0.87, 0.95)
@export var ground_base := Color(0.47, 0.72, 0.38)
@export var ground_base_dark := Color(0.41, 0.65, 0.33)
@export var ground_patch := Color(0.93, 0.84, 0.6)
@export var ground_patch_dark := Color(0.88, 0.78, 0.53)
@export_range(0.0, 1.0) var patch_amount := 0.45
@export var props: Array[PropData] = []
## Mar a partir de esta x (en metros); funciona como borde del mapa. INF = sin mar.
@export var water_from_x := INF

@export_group("Terreno")
## Niveles de mesetas por encima del piso (0 = plano).
@export var terrain_levels := 2
## Alto de cada escalón en metros (un salto sube un escalón).
@export var step_height := 1.0
@export var terrain_frequency := 0.035
## Radio plano alrededor del inicio (m).
@export var flat_radius := 10.0
@export var cliff_color := Color(0.78, 0.62, 0.42)
@export var cliff_dark := Color(0.62, 0.47, 0.3)
## Probabilidad de cascada en cada borde de acantilado que mira a la cámara.
@export_range(0.0, 1.0) var waterfall_chance := 0.04

@export_group("Fondo")
@export var mountain_color := Color(0.55, 0.7, 0.62)
@export var mountain_far_color := Color(0.68, 0.8, 0.86)


func wave_at(time: float) -> WaveData:
	for w in waves:
		if time >= w.start and time < w.end:
			return w
	return waves.back() if not waves.is_empty() else null
