extends Node
## Carga los sprites de cada especie desde assets/sprites/digimon/<Especie>/<Especie>.json
## (generados por blender/scripts/render_anims.py) y los cachea.

const SPRITES_DIR := "res://assets/sprites/digimon/"

var _cache := {}


## Devuelve { size, anchor, radius, anims: { nombre: { texture, frames, fps, loop } } }.
## anchor = punto de los pies dentro del frame; radius = radio de colisión aproximado.
func species(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var base := SPRITES_DIR + name + "/"
	var file := FileAccess.open(base + name + ".json", FileAccess.READ)
	if file == null:
		push_error("DigimonDB: no hay sprites para %s" % name)
		return {}
	var manifest: Dictionary = JSON.parse_string(file.get_as_text())
	var size := int(manifest["tamano_frame"])
	var anims := {}
	for anim_name in manifest["animaciones"]:
		var a: Dictionary = manifest["animaciones"][anim_name]
		anims[anim_name] = {
			"texture": load(base + "%s_%s.png" % [name, anim_name]) as Texture2D,
			"frames": int(a["frames"]),
			"fps": float(a["fps"]),
			"loop": bool(a["loop"]),
		}
	var info := {"size": size, "anims": anims, "anchor": Vector2(size * 0.5, size), "radius": size * 0.15}
	_measure(info)
	_cache[name] = info
	return info


## Pies y ancho a partir de los píxeles usados del primer frame del idle.
func _measure(info: Dictionary) -> void:
	var idle: Dictionary = info["anims"].get("idle", {})
	if idle.is_empty():
		return
	var size: int = info["size"]
	var image: Image = idle["texture"].get_image()
	if image == null:
		return
	var used := image.get_region(Rect2i(0, 0, size, size)).get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	info["anchor"] = Vector2(used.position.x + used.size.x * 0.5, used.end.y)
	info["radius"] = clampf(used.size.x * 0.35, 4.0, 40.0)


## SpriteFrames para AnimatedSprite2D a partir de las tiras horizontales.
func sprite_frames(name: String) -> SpriteFrames:
	var info := species(name)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var size: int = info["size"]
	for anim_name in info["anims"]:
		var a: Dictionary = info["anims"][anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, a["fps"])
		frames.set_animation_loop(anim_name, a["loop"])
		for i in a["frames"]:
			var atlas := AtlasTexture.new()
			atlas.atlas = a["texture"]
			atlas.region = Rect2(i * size, 0, size, size)
			frames.add_frame(anim_name, atlas)
	return frames
