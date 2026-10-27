class_name PropData
extends Resource
## Decorado de papel de un mapa (árboles, palmeras, rocas, cabinas de teléfono...).
## Se reparte por chunks de forma determinística, así cada mapa se ve igual en cada run.

enum Shape { TREE, PALM, ROCK, PHONE_BOOTH, FLOWER, SHELL, BUSH, MOUNTAIN, GRASS, CHEST }

@export var shape := Shape.TREE
@export var color_a := Color(0.3, 0.62, 0.3)
@export var color_b := Color(0.55, 0.36, 0.2)
@export var color_c := Color(0.9, 0.9, 0.95)
## Instancias por chunk (12 x 12 m) en promedio.
@export var density := 2.0
## Alto en metros (min, max).
@export var height := Vector2(2.0, 3.0)
## Ancho / alto del recorte.
@export var aspect := 0.8
## Si > 1, aparecen en fila (ej. la fila de cabinas de teléfono de la playa de File Island).
@export var row := 1
@export var row_spacing := 1.6
## Si es true, se ubica sobre la orilla del mar (a `shore_offset` metros de la línea de agua).
@export var on_shore := false
@export var shore_offset := 3.0
