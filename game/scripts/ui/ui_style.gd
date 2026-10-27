class_name UIStyle
extends RefCounted
## Estilo visual de la interfaz: paneles de vidrio oscuro redondeados, acentos naranja/azul,
## texto blanco nítido. Lo usan el menú (con Controls reales) y el HUD (dibujado).

const BG := Color(0.06, 0.08, 0.13, 0.86)
const BG_SOLID := Color(0.08, 0.1, 0.16)
const BORDER := Color(1, 1, 1, 0.09)
const TEXT := Color(0.96, 0.97, 1.0)
const MUTED := Color(0.66, 0.7, 0.8)
const ACCENT := Color(1.0, 0.56, 0.16)
const ACCENT_2 := Color(0.27, 0.53, 1.0)
const GOOD := Color(0.3, 0.86, 0.48)
const WARN := Color(1.0, 0.78, 0.25)
const BAD := Color(1.0, 0.33, 0.33)
const RADIUS := 10

static var _font_bold: FontVariation
static var _theme: Theme


static func font() -> Font:
	return ThemeDB.fallback_font


static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = FontVariation.new()
		_font_bold.base_font = ThemeDB.fallback_font
		_font_bold.variation_embolden = 0.8
	return _font_bold


static func panel(bg := BG, radius := RADIUS, border := BORDER, shadow := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.0 else 0)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, 3)
	sb.anti_aliasing = true
	sb.set_content_margin_all(8)
	return sb


## Tema para los Controls del menú.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 12
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := panel(ACCENT_2, 8, Color(1, 1, 1, 0.15), 4)
		match state:
			"hover": sb.bg_color = ACCENT_2.lightened(0.15)
			"pressed": sb.bg_color = ACCENT_2.darkened(0.2)
			"disabled": sb.bg_color = Color(0.3, 0.33, 0.4)
			"focus":
				sb.bg_color = Color.TRANSPARENT
				sb.border_color = Color(1, 1, 1, 0.5)
				sb.set_border_width_all(2)
				sb.shadow_size = 0
		sb.set_content_margin_all(6)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_font("font", "Button", font_bold())
	var le := panel(Color(0.02, 0.03, 0.06, 0.7), 8, Color(1, 1, 1, 0.14), 0)
	le.set_content_margin_all(6)
	t.set_stylebox("normal", "LineEdit", le)
	var lef := le.duplicate()
	lef.border_color = ACCENT
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_color("font_color", "Label", TEXT)
	_theme = t
	return t


## Botón principal (naranja) o secundario (azul / rojo / verde).
static func style_button(b: Button, color: Color, font_size := 13) -> void:
	for state in ["normal", "hover", "pressed"]:
		var sb := panel(color, 9, Color(1, 1, 1, 0.18), 6)
		if state == "hover":
			sb.bg_color = color.lightened(0.15)
		elif state == "pressed":
			sb.bg_color = color.darkened(0.2)
		sb.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_font_size_override("font_size", font_size)


## Barra redondeada (vida, XP, jefes).
static func draw_bar(ci: CanvasItem, r: Rect2, frac: float, color: Color, back := Color(0, 0, 0, 0.45), ghost := -1.0) -> void:
	var radius := int(r.size.y / 2)
	var bg := StyleBoxFlat.new()
	bg.bg_color = back
	bg.set_corner_radius_all(radius)
	bg.anti_aliasing = true
	ci.draw_style_box(bg, r)
	if ghost > frac:
		var g := bg.duplicate()
		g.bg_color = Color(1, 1, 1, 0.45)
		ci.draw_style_box(g, Rect2(r.position, Vector2(maxf(r.size.x * ghost, r.size.y), r.size.y)))
	if frac > 0.0:
		var fg := bg.duplicate()
		fg.bg_color = color
		ci.draw_style_box(fg, Rect2(r.position, Vector2(maxf(r.size.x * clampf(frac, 0, 1), r.size.y), r.size.y)))
		var shine := bg.duplicate()
		shine.bg_color = Color(1, 1, 1, 0.22)
		ci.draw_style_box(shine, Rect2(r.position + Vector2(2, 1), Vector2(maxf(r.size.x * clampf(frac, 0, 1) - 4, 1), r.size.y * 0.35)))
