class_name Terrain
extends RefCounted
## Terreno de mesetas en escalones (celdas de 1 m). Lo comparten la simulación (alturas, saltos,
## acantilados) y PaperView (malla), así lo que se ve es exactamente lo que se juega.

const PX := 32.0  # píxeles de simulación por metro (igual que PaperView)

var levels := 2
var step := 1.0
var flat_radius := 10.0
var water_from := INF
var _noise := FastNoiseLite.new()


func _init(stage: StageData) -> void:
	levels = stage.terrain_levels
	step = stage.step_height
	flat_radius = stage.flat_radius
	water_from = stage.water_from_x
	_noise.seed = hash(stage.display_name)
	_noise.frequency = stage.terrain_frequency
	_noise.fractal_octaves = 3


## Nivel (0..levels) de la celda (cx, cz) en metros.
func level_at_cell(cx: int, cz: int) -> int:
	if levels <= 0:
		return 0
	var x := cx + 0.5
	var z := cz + 0.5
	var n := _noise.get_noise_2d(x, z)  # ~ -0.6..0.6
	# plano alrededor del inicio y cerca del mar
	n -= 0.6 * (1.0 - smoothstep(flat_radius, flat_radius + 10.0, Vector2(x, z).length()))
	if water_from != INF:
		n -= 0.6 * (1.0 - clampf((water_from - 6.0 - x) / 8.0, 0.0, 1.0))
	return clampi(floori((n - 0.05) * 8.0), 0, levels)


## Altura del piso (m) debajo de una posición de simulación (px).
func height_at(pos_px: Vector2) -> float:
	return level_at_cell(floori(pos_px.x / PX), floori(pos_px.y / PX)) * step
