extends SceneTree
## Genera el ícono/favicon y la imagen de presentación a partir del sprite de Agumon.
## Uso: godot --headless --path game --script ../tools/make_branding.gd

const SPRITE := "res://assets/sprites/digimon/Agumon/Agumon_idle.png"
const ORANGE := Color(1.0, 0.56, 0.16)
const ORANGE_DARK := Color(0.85, 0.38, 0.08)
const NAVY := Color(0.07, 0.09, 0.16)


func _init() -> void:
	var strip: Texture2D = load(SPRITE)
	var img := strip.get_image()
	img.decompress()
	var frame := img.get_region(Rect2i(0, 0, img.get_height(), img.get_height()))
	var used := frame.get_used_rect()
	var agumon := frame.get_region(used)
	_save_icon(agumon, 256, "res://icon.png")
	_save_icon(agumon, 512, "res://assets/branding/splash.png", NAVY, false)
	print("branding listo")
	quit()


## Fondo redondeado (naranja con degradé) y Agumon centrado, escalado entero sin suavizar.
func _save_icon(agumon: Image, size: int, path: String, bg := ORANGE, gradient := true) -> void:
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var radius := size * 0.22
	for y in size:
		for x in size:
			var inside := _rounded(x + 0.5, y + 0.5, size, radius)
			if inside:
				var c := bg.lerp(ORANGE_DARK, float(y) / size) if gradient else bg
				out.set_pixel(x, y, c)
	var k := int(floor(size * 0.78 / maxi(agumon.get_width(), agumon.get_height())))
	var scaled := agumon.duplicate()
	scaled.resize(agumon.get_width() * k, agumon.get_height() * k, Image.INTERPOLATE_NEAREST)
	# sombra y borde blanco de papel
	var off := Vector2i((size - scaled.get_width()) / 2, (size - scaled.get_height()) / 2 + size / 40)
	for y in scaled.get_height():
		for x in scaled.get_width():
			if scaled.get_pixel(x, y).a < 0.5:
				continue
			for d in [Vector2i(-k, 0), Vector2i(k, 0), Vector2i(0, -k), Vector2i(0, k), Vector2i(k, k)]:
				var p: Vector2i = off + Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < size and p.y < size and out.get_pixel(p.x, p.y).a > 0.0:
					out.set_pixel(p.x, p.y, Color(0.98, 0.96, 0.9) if d != Vector2i(k, k) else out.get_pixel(p.x, p.y))
	out.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), off)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	out.save_png(path)


func _rounded(x: float, y: float, size: int, r: float) -> bool:
	var cx := clampf(x, r, size - r)
	var cy := clampf(y, r, size - r)
	return Vector2(x - cx, y - cy).length() <= r
