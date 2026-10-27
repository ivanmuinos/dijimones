class_name SpatialHash
extends RefCounted
## Grilla uniforme para consultas de cercanía sin usar la física de Godot (PRD 8.3).

var cell_size := 48.0
var _cells := {}


func _init(size := 48.0) -> void:
	cell_size = size


func clear() -> void:
	_cells.clear()


func insert(index: int, pos: Vector2) -> void:
	var key := Vector2i(floori(pos.x / cell_size), floori(pos.y / cell_size))
	if _cells.has(key):
		_cells[key].append(index)
	else:
		_cells[key] = [index]


## Índices en las celdas que tocan el círculo (hay que filtrar por distancia después).
func query(pos: Vector2, radius: float) -> Array:
	var out := []
	var x0 := floori((pos.x - radius) / cell_size)
	var x1 := floori((pos.x + radius) / cell_size)
	var y0 := floori((pos.y - radius) / cell_size)
	var y1 := floori((pos.y + radius) / cell_size)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var key := Vector2i(x, y)
			if _cells.has(key):
				out.append_array(_cells[key])
	return out
