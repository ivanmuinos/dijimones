class_name PaperView
extends Node3D
## Dibuja la simulación (2D, en píxeles) como un mundo 3D de papel estilo Paper Mario:
## Digimon como recortes de papel con borde blanco, terreno de mesetas con acantilados y cascadas,
## decorados de papel, montañas de fondo y cámara en perspectiva con zoom.
## No toca la lógica: solo lee el estado de la simulación.

const PX := 32.0  # píxeles de simulación por metro
const CHUNK := 12.0  # chunks de decorado (m)
const TERRAIN_CHUNK := 16  # celdas por chunk de terreno
const CHUNK_RANGE_X := 2
const CHUNK_RANGE_Z := Vector2i(-3, 1)  # la cámara mira hacia -z: se ve más hacia atrás
const CAMERA_OFFSET := Vector3(0, 8.5, 8.0)
const ZOOM_RANGE := Vector2(0.5, 1.9)
const TURN_SPEED := 7.0  # giro de "hoja de papel"
## Los Digimon se dibujan más grandes que su tamaño de simulación, para que se lean bien entre el decorado.
const CHAR_SCALE := 1.5
const SPRITE_SHADER := preload("res://shaders/paper_sprite.gdshader")
const FLAT_SHADER := preload("res://shaders/paper_flat.gdshader")
const PROP_SHADER := preload("res://shaders/paper_prop.gdshader")
const GROUND_SHADER := preload("res://shaders/paper_ground.gdshader")
const CLIFF_SHADER := preload("res://shaders/paper_cliff.gdshader")
const WATER_SHADER := preload("res://shaders/paper_water.gdshader")

var stage: StageData
var terrain: Terrain
var player: Player
var enemies: EnemyField
var projectiles: Projectiles
var gems: XpGems
var arsenal: Arsenal
var hazards: Hazards

var camera := Camera3D.new()
var zoom := 1.0
var _target := Vector3.ZERO
var _materials := {}
var _chunks := {}  # Vector2i -> MeshInstance3D
var _player_card: Dictionary
var _player_turn := 1.0
var _enemy_cards := {}  # especie -> card
var _shadows: MultiMeshInstance3D
var _shots: MultiMeshInstance3D
var _enemy_shots: MultiMeshInstance3D
var _gems: MultiMeshInstance3D
var _rings: MultiMeshInstance3D
var _chests: MultiMeshInstance3D
var _mountains: Array[MultiMeshInstance3D] = []
var _props: Array[MultiMeshInstance3D] = []
var _props_chunk := Vector2i(1 << 30, 0)
var _effects: Array = []  # [pos3d, radio m, tiempo restante, duración, color]


func setup(p_stage: StageData) -> void:
	stage = p_stage
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = stage.sky_color
	add_child(env)

	camera.fov = 38.0
	camera.near = 0.5
	camera.far = 160.0
	add_child(camera)

	_materials["ground"] = _ground_material()
	var cliff := ShaderMaterial.new()
	cliff.shader = CLIFF_SHADER
	cliff.set_shader_parameter("cliff_color", stage.cliff_color)
	cliff.set_shader_parameter("cliff_dark", stage.cliff_dark)
	_materials["cliff"] = cliff
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	_materials["water"] = water

	_shadows = _flat_multimesh(0, false, true)
	_rings = _flat_multimesh(3, false, true)
	_shots = _flat_multimesh(1, true, false)
	_enemy_shots = _flat_multimesh(1, true, false)
	_gems = _flat_multimesh(2, true, false)
	var chest := PropData.new()
	chest.shape = PropData.Shape.CHEST
	chest.color_a = Color(0.95, 0.75, 0.2)
	chest.color_b = Color(0.6, 0.35, 0.18)
	chest.color_c = Color(0.3, 0.25, 0.2)
	chest.aspect = 1.1
	_chests = _prop_multimesh(chest)
	for c in [stage.mountain_far_color, stage.mountain_color]:
		var m := PropData.new()
		m.shape = PropData.Shape.MOUNTAIN
		m.color_a = c
		m.color_c = Color(0.97, 0.97, 1.0)
		m.aspect = 1.6
		_mountains.append(_prop_multimesh(m))
	for prop in stage.props:
		_props.append(_prop_multimesh(prop))


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, ZOOM_RANGE.x, ZOOM_RANGE.y)


func shockwave(radius_px: float) -> void:
	_effects.append([_player_3d_floor(), radius_px / PX, 0.6, 0.6, Color(1, 1, 0.75)])


func special(radius_px: float, color: Color) -> void:
	_effects.append([_player_3d_floor(), radius_px / PX, 0.8, 0.8, color])
	_effects.append([_player_3d_floor(), radius_px / PX * 0.6, 0.5, 0.5, Color.WHITE])


func render(delta: float) -> void:
	var floor_p := _player_3d_floor()
	_target = _target.lerp(floor_p, clampf(delta * 8.0, 0.0, 1.0)) if _target != Vector3.ZERO else floor_p
	camera.position = _target + CAMERA_OFFSET * zoom
	camera.look_at(_target + Vector3(0, 0.5, 0))
	_update_terrain(floor_p)
	_update_props(floor_p)
	_render_mountains()
	_render_player(delta)
	_render_enemies()
	_render_shadows()
	_render_shots()
	_render_gems()
	_render_chests()
	for s in hazards.slams_now:
		_effects.append([to_3d(s[0], _h(s[0]) + 0.03), s[1] / PX, 0.35, 0.35, Color(1, 0.9, 0.8)])
	_render_rings(delta)


static func to_3d(v: Vector2, height := 0.0) -> Vector3:
	return Vector3(v.x / PX, height, v.y / PX)


func _h(pos_px: Vector2) -> float:
	return terrain.height_at(pos_px)


func _player_3d_floor() -> Vector3:
	return to_3d(player.position, player.floor_height)


# --- Terreno -------------------------------------------------------------------------------------

func _ground_material() -> ShaderMaterial:
	var gm := ShaderMaterial.new()
	gm.shader = GROUND_SHADER
	gm.set_shader_parameter("base_color", stage.ground_base)
	gm.set_shader_parameter("base_dark", stage.ground_base_dark)
	gm.set_shader_parameter("patch_color", stage.ground_patch)
	gm.set_shader_parameter("patch_dark", stage.ground_patch_dark)
	gm.set_shader_parameter("patch_amount", stage.patch_amount)
	if stage.water_from_x != INF:
		gm.set_shader_parameter("water_from", stage.water_from_x)
	return gm


func _update_terrain(p: Vector3) -> void:
	var c := Vector2i(floori(p.x / TERRAIN_CHUNK), floori(p.z / TERRAIN_CHUNK))
	var wanted := {}
	for cx in range(c.x - 2, c.x + 3):
		for cz in range(c.y - 3, c.y + 2):
			var key := Vector2i(cx, cz)
			wanted[key] = true
			if not _chunks.has(key):
				_chunks[key] = _build_chunk(cx, cz)
	for key in _chunks.keys():
		if not wanted.has(key):
			_chunks[key].queue_free()
			_chunks.erase(key)


## Malla de un chunk: tapas de cada celda a su altura, paredes donde el vecino es más bajo,
## y cascadas en algunas paredes que miran a la cámara.
func _build_chunk(cx: int, cz: int) -> MeshInstance3D:
	var n := TERRAIN_CHUNK
	var lv := {}
	for x in range(-1, n + 1):
		for z in range(-1, n + 1):
			lv[Vector2i(x, z)] = terrain.level_at_cell(cx * n + x, cz * n + z)
	var tops := SurfaceTool.new()
	var walls := SurfaceTool.new()
	var water := SurfaceTool.new()
	for st in [tops, walls, water]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts := [0, 0, 0]
	var step := terrain.step
	for x in n:
		for z in n:
			var gx := cx * n + x
			var gz := cz * n + z
			var l: int = lv[Vector2i(x, z)]
			var h := l * step
			_quad(tops, Vector3(gx, h, gz), Vector3(gx + 1, h, gz), Vector3(gx + 1, h, gz + 1), Vector3(gx, h, gz + 1))
			counts[0] += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nl: int = lv[Vector2i(x, z) + d]
				if nl >= l:
					continue
				var nh := nl * step
				var a: Vector3
				var b: Vector3
				match d:
					Vector2i(1, 0):
						a = Vector3(gx + 1, 0, gz)
						b = Vector3(gx + 1, 0, gz + 1)
					Vector2i(-1, 0):
						a = Vector3(gx, 0, gz + 1)
						b = Vector3(gx, 0, gz)
					Vector2i(0, 1):
						a = Vector3(gx + 1, 0, gz + 1)
						b = Vector3(gx, 0, gz + 1)
					_:
						a = Vector3(gx, 0, gz)
						b = Vector3(gx + 1, 0, gz)
				_quad(walls, a + Vector3(0, h, 0), b + Vector3(0, h, 0), b + Vector3(0, nh, 0), a + Vector3(0, nh, 0))
				counts[1] += 1
				# cascada: solo en paredes que miran a la cámara (+z)
				if d == Vector2i(0, 1) and _chance(gx, gz) < stage.waterfall_chance:
					var off := Vector3(0, 0, 0.04)
					water.set_color(Color(0, 0, 0))
					_quad(water, a + Vector3(-0.1, h, 0) + off, b + Vector3(0.1, h, 0) + off,
						b + Vector3(0.1, nh, 0) + off, a + Vector3(-0.1, nh, 0) + off)
					water.set_color(Color(1, 0, 0))
					var pc := Vector3(gx + 0.5, nh + 0.02, gz + 1.7)
					_quad(water, pc + Vector3(-1.2, 0, -0.7), pc + Vector3(1.2, 0, -0.7), pc + Vector3(1.2, 0, 0.7), pc + Vector3(-1.2, 0, 0.7))
					counts[2] += 2
	var mesh := ArrayMesh.new()
	var names := ["ground", "cliff", "water"]
	var tools := [tops, walls, water]
	for k in 3:
		if counts[k] > 0:
			tools[k].commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _materials[names[k]])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	return mi


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [c, Vector2(1, 1)], [a, Vector2(0, 0)], [c, Vector2(1, 1)], [d, Vector2(0, 1)]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])


func _chance(x: int, z: int) -> float:
	return float(absi(hash(Vector2i(x, z))) % 10000) / 10000.0


# --- Digimon -------------------------------------------------------------------------------------

## Quad de papel para una especie: un MultiMesh por textura (tira de animación).
func _card(species: String, anim: String) -> Dictionary:
	var info := DigimonDB.species(species)
	var a: Dictionary = info["anims"].get(anim, info["anims"]["idle"])
	var size: float = info["size"]
	var anchor: Vector2 = info["anchor"]
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size) / PX * CHAR_SCALE
	# el punto de los pies (anchor) queda en el origen de la instancia
	quad.center_offset = Vector3((size * 0.5 - anchor.x) / PX, (anchor.y - size * 0.5) / PX, 0) * CHAR_SCALE
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	mat.set_shader_parameter("sprite", a["texture"])
	mat.set_shader_parameter("frames", float(a["frames"]))
	mat.set_shader_parameter("frame_size", size)
	quad.material = mat
	var mmi := _multimesh_instance(quad)
	return {"mmi": mmi, "info": info, "anim": a, "species": species, "anim_name": anim}


func _multimesh_instance(mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


func _ensure_capacity(mm: MultiMesh, n: int) -> void:
	if mm.instance_count < n:
		mm.instance_count = maxi(maxi(n, mm.instance_count * 2), 16)
	mm.visible_instance_count = n


func _render_player(delta: float) -> void:
	var species := player.species()
	var anim := player.anim_name()
	if _player_card.is_empty() or _player_card["species"] != species or _player_card["anim_name"] != anim:
		if not _player_card.is_empty():
			_player_card["mmi"].queue_free()
		_player_card = _card(species, anim)
	var target := -1.0 if player.facing_left() else 1.0
	_player_turn = move_toward(_player_turn, target, TURN_SPEED * delta)
	var mm: MultiMesh = _player_card["mmi"].multimesh
	_ensure_capacity(mm, 1)
	mm.set_instance_transform(0, Transform3D(Basis(), to_3d(player.position, player.z)))
	var flash := 0.6 if player.hurt_flash() else 0.0
	mm.set_instance_custom_data(0, Color(player.anim_frame(), _player_turn, flash, 0))


func _render_enemies() -> void:
	var counts := {}
	for i in enemies.count():
		var sp := enemies.data_of(i).species
		counts[sp] = counts.get(sp, 0) + 1
	for sp in counts:
		if not _enemy_cards.has(sp):
			_enemy_cards[sp] = _card(sp, "correr")
	var cursor := {}
	for sp in _enemy_cards:
		_ensure_capacity(_enemy_cards[sp]["mmi"].multimesh, counts.get(sp, 0))
		cursor[sp] = 0
	for i in enemies.count():
		var data := enemies.data_of(i)
		var card: Dictionary = _enemy_cards[data.species]
		var mm: MultiMesh = card["mmi"].multimesh
		var a: Dictionary = card["anim"]
		var k: int = cursor[data.species]
		cursor[data.species] = k + 1
		var s := data.scale
		mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(s, s, s)), to_3d(enemies.pos[i], _h(enemies.pos[i]))))
		var frame := int(enemies.anim_time[i] * a["fps"]) % int(a["frames"])
		# parpadea mientras un jefe prepara su ataque
		var flash := 0.8 if enemies.flash[i] > 0.0 and fmod(enemies.flash[i], 0.16) > 0.08 else 0.0
		mm.set_instance_custom_data(k, Color(frame, enemies.turn[i], flash, 0))


# --- Formas planas -------------------------------------------------------------------------------

func _flat_multimesh(kind: int, billboard: bool, on_ground: bool) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	if on_ground:
		quad.orientation = PlaneMesh.FACE_Y
	var mat := ShaderMaterial.new()
	mat.shader = FLAT_SHADER
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("billboard", billboard)
	quad.material = mat
	return _multimesh_instance(quad)


func _render_shadows() -> void:
	var mm := _shadows.multimesh
	var n := enemies.count() + 1
	_ensure_capacity(mm, n)
	# la sombra del jugador se achica cuando salta
	var r := player.radius() / PX * 2.6 * CHAR_SCALE / (1.0 + (player.z - player.floor_height) * 0.6)
	mm.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3(r, 1, r * 0.6)), _player_3d_floor() + Vector3(0, 0.01, 0)))
	mm.set_instance_custom_data(0, Color(0, 0, 0, 1))
	for i in enemies.count():
		var er := enemies.radius_of(i) / PX * 2.6 * CHAR_SCALE
		mm.set_instance_transform(i + 1, Transform3D(Basis.from_scale(Vector3(er, 1, er * 0.6)), to_3d(enemies.pos[i], _h(enemies.pos[i]) + 0.01)))
		mm.set_instance_custom_data(i + 1, Color(0, 0, 0, 1))


func _render_shots() -> void:
	var mm := _shots.multimesh
	var n := projectiles.pos.size()
	_ensure_capacity(mm, n)
	for i in n:
		var s := projectiles.radius[i] / PX * 2.4
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), to_3d(projectiles.pos[i], _h(projectiles.pos[i]) + 0.6)))
		mm.set_instance_custom_data(i, projectiles.color[i])
	mm = _enemy_shots.multimesh
	n = hazards.shot_pos.size()
	_ensure_capacity(mm, n)
	for i in n:
		var p := hazards.shot_pos[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.45, 0.45, 0.45)), to_3d(p, _h(p) + 0.7)))
		mm.set_instance_custom_data(i, Color(0.55, 0.2, 0.75))


func _render_gems() -> void:
	var mm := _gems.multimesh
	var n := gems.pos.size()
	_ensure_capacity(mm, n)
	var t := Time.get_ticks_msec() * 0.004
	for i in n:
		var c := Color(0.35, 0.85, 1.0)
		if gems.value[i] >= 10:
			c = Color(1.0, 0.3, 0.4)
		elif gems.value[i] >= 3:
			c = Color(0.4, 1.0, 0.5)
		var h := _h(gems.pos[i]) + 0.35 + sin(t + i) * 0.08
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.3, 0.4, 0.3)), to_3d(gems.pos[i], h)))
		mm.set_instance_custom_data(i, c)


func _render_chests() -> void:
	var mm := _chests.multimesh
	var n := hazards.chests.size()
	_ensure_capacity(mm, n)
	var bob := absf(sin(Time.get_ticks_msec() * 0.005)) * 0.25
	for i in n:
		var p := hazards.chests[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(0.9, 0.9, 0.9)), to_3d(p, _h(p) + bob)))
		mm.set_instance_custom_data(i, Color(1, 0, 0, 0))


## Anillos en el piso: aura de Fire Wall, avisos de golpe de jefe (se llenan) y efectos.
func _render_rings(delta: float) -> void:
	var mm := _rings.multimesh
	var rings := []
	for w in arsenal.weapons:
		if w.kind == WeaponData.Kind.AURA:
			rings.append([_player_3d_floor() + Vector3(0, 0.02, 0), arsenal.aura_radius(w) / PX, Color(w.color, 0.5 + arsenal.aura_pulse())])
	for k in hazards.warn_pos.size():
		var p := hazards.warn_pos[k]
		var t := 1.0 - hazards.warn_left[k] / hazards.warn_total[k]
		var at := to_3d(p, _h(p) + 0.03)
		rings.append([at, hazards.warn_radius[k] / PX, Color(1, 0.2, 0.15, 0.5)])
		rings.append([at, hazards.warn_radius[k] / PX * t, Color(1, 0.35, 0.2, 0.9)])
	for e in _effects:
		e[2] -= delta
		var t: float = 1.0 - e[2] / e[3]
		rings.append([e[0] + Vector3(0, 0.04, 0), e[1] * t, Color(e[4], 1.0 - t)])
	_effects = _effects.filter(func(e): return e[2] > 0.0)
	_ensure_capacity(mm, rings.size())
	for k in rings.size():
		var d: float = rings[k][1] * 2.0
		mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(d, 1, d)), rings[k][0]))
		mm.set_instance_custom_data(k, rings[k][2])


# --- Decorados -----------------------------------------------------------------------------------

func _prop_multimesh(prop: PropData) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(prop.aspect, 1.0)
	quad.center_offset = Vector3(0, 0.5, 0)
	var mat := ShaderMaterial.new()
	mat.shader = PROP_SHADER
	mat.set_shader_parameter("shape", prop.shape)
	mat.set_shader_parameter("color_a", prop.color_a)
	mat.set_shader_parameter("color_b", prop.color_b)
	mat.set_shader_parameter("color_c", prop.color_c)
	quad.material = mat
	return _multimesh_instance(quad)


## Dos filas de montañas de papel de fondo, que se repiten en x y siempre quedan detrás.
func _render_mountains() -> void:
	for layer in _mountains.size():
		var mm := _mountains[layer].multimesh
		var count := 12
		_ensure_capacity(mm, count)
		var spacing := 22.0 - layer * 6.0
		var dist := 70.0 - layer * 22.0
		var base_x := floorf(_target.x / spacing) * spacing
		for k in count:
			var x := base_x + (k - count / 2) * spacing
			var rnd := float(absi(hash(Vector2i(int(x), layer))) % 1000) / 1000.0
			var h := (28.0 - layer * 9.0) * (0.7 + 0.5 * rnd)
			var pos := Vector3(x + rnd * 6.0, -1.0, _target.z - dist)
			mm.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(h, h, h)), pos))
			mm.set_instance_custom_data(k, Color(rnd, 0, 0, 0))


## Reparte los decorados en los chunks cercanos; se recalcula solo al cambiar de chunk.
func _update_props(p: Vector3) -> void:
	var chunk := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	if chunk == _props_chunk:
		return
	_props_chunk = chunk
	for k in stage.props.size():
		var prop: PropData = stage.props[k]
		var items := []
		for cx in range(chunk.x - CHUNK_RANGE_X, chunk.x + CHUNK_RANGE_X + 1):
			for cz in range(chunk.y + CHUNK_RANGE_Z.x, chunk.y + CHUNK_RANGE_Z.y + 1):
				var rng := RandomNumberGenerator.new()
				rng.seed = hash(Vector3i(cx, cz, k))
				var n := int(prop.density) + int(rng.randf() < fmod(prop.density, 1.0))
				for j in n:
					var origin := Vector3((cx + rng.randf()) * CHUNK, 0, (cz + rng.randf()) * CHUNK)
					if prop.on_shore:
						if cx != floori((stage.water_from_x - prop.shore_offset) / CHUNK):
							continue
						origin.x = stage.water_from_x - prop.shore_offset
					elif origin.x > stage.water_from_x - 1.0:
						continue
					var h := rng.randf_range(prop.height.x, prop.height.y)
					var variant := rng.randf()
					for r in prop.row:
						var offset := Vector3(0, 0, r * prop.row_spacing) if prop.on_shore else Vector3(r * prop.row_spacing, 0, 0)
						var at := origin + offset
						at.y = terrain.level_at_cell(floori(at.x), floori(at.z)) * terrain.step
						items.append([at, h, variant])
		var mm := _props[k].multimesh
		_ensure_capacity(mm, items.size())
		for j in items.size():
			var h: float = items[j][1]
			mm.set_instance_transform(j, Transform3D(Basis.from_scale(Vector3(h, h, h)), items[j][0]))
			mm.set_instance_custom_data(j, Color(items[j][2], 0, 0, 0))
