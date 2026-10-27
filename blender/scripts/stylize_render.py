"""Dijimones: estiliza un modelo base y lo renderiza a sprites (PRD 9.3, estética unificada).

Uso:
  blender -b -P blender/scripts/stylize_render.py -- <modelo.fbx> <nombre> <salida_dir> [--etapa Rookie]

Pasos:
  1. Importa el modelo y aplica la pose de reposo.
  2. Normaliza escala (altura fija por etapa) y lo centra en el piso.
  3. Decima a un presupuesto de triángulos fijo.
  4. Reemplaza texturas por una paleta plana: muestrea el color de cada cara y lo cuantiza a N colores.
  5. Shader toon de 3 tonos + contorno (inverted hull) del mismo grosor para todos.
  6. Renderiza 8 direcciones con cámara ortográfica fija y fondo transparente.
"""
import math
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Vector

# --- Parámetros de estilo (iguales para todos los Digimon) ---
ALTURA_POR_ETAPA = {"In-Training": 0.6, "Rookie": 1.0, "Champion": 1.6, "Ultimate": 2.0, "Mega": 2.4}
TRIS_POR_ETAPA = {"In-Training": 800, "Rookie": 1500, "Champion": 2200, "Ultimate": 2600, "Mega": 3000}
COLORES_PALETA = 8
TONOS_TOON = (0.55, 0.8, 1.0)  # sombra, medio, luz
GROSOR_CONTORNO = 0.018
COLOR_CONTORNO = (0.06, 0.05, 0.08, 1.0)
CAMARA_ELEVACION = 35.0  # grados
CAMARA_ORTHO = 3.0       # misma escala para todos: los Mega se ven más grandes
RESOLUCION = 96          # pixel art: un Rookie queda de ~32 px de alto
PIXEL_ART = True         # sin antialiasing, alpha duro y contorno de 1 px alrededor de la silueta
PREVIEW_ESCALA = 4       # copia ampliada (vecino más cercano) para mirar los sprites
DIRECCIONES = 8


def args():
    argv = sys.argv[sys.argv.index("--") + 1:]
    etapa = "Rookie"
    if "--etapa" in argv:
        i = argv.index("--etapa")
        etapa = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    return argv[0], argv[1], argv[2], etapa


def limpiar_escena():
    bpy.ops.wm.read_factory_settings(use_empty=True)


POSE_ACCION = "_bn01"  # idle de batalla en los modelos de Cyber Sleuth


def importar(path):
    bpy.ops.import_scene.fbx(filepath=path)


def textura_base(path):
    """chrNNNa01.png (o chrNNNa01a.png); el nombre del FBX puede traer sufijos ("chr716 anims.fbx")."""
    carpeta = os.path.dirname(path)
    m = re.search(r"chr\d+", os.path.basename(path))
    if not m:
        return None
    for sufijo in ("a01.png", "a01a.png"):
        png = os.path.join(carpeta, m.group(0) + sufijo)
        if os.path.exists(png):
            return png
    return None


def asignar_texturas(path):
    """Los FBX de Cyber Sleuth no traen la textura conectada: chrNNN*.fbx -> chrNNNa01.png."""
    png = textura_base(path)
    if png is None:
        return
    img = bpy.data.images.load(png)
    for mat in bpy.data.materials:
        mat.use_nodes = True
        nt = mat.node_tree
        if any(n.type == "TEX_IMAGE" and n.image for n in nt.nodes):
            continue
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def borrar_contorno_original():
    for o in [o for o in bpy.data.objects if o.type == "MESH"]:
        # el contorno del juego original es una malla sin UVs (o con material "line")
        sin_uv = len(o.data.uv_layers) == 0
        if sin_uv or any(s.material and "line" in s.material.name.lower() for s in o.material_slots):
            bpy.data.objects.remove(o)


def posar(accion=POSE_ACCION):
    """Primer frame del idle en vez de la T-pose de reposo."""
    for arm in [o for o in bpy.data.objects if o.type == "ARMATURE"]:
        act = next((a for a in bpy.data.actions if a.name.endswith(accion)), None)
        if act is None:
            arm.data.pose_position = "REST"
            continue
        arm.animation_data_create()
        arm.animation_data.action = act
        if getattr(act, "slots", None) and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
        arm.data.pose_position = "POSE"
    bpy.context.scene.frame_set(1)


def unificar_malla(up="Y"):
    """Aplica la pose, borra huesos, une las mallas en un objeto y lo deja con Z hacia arriba."""
    mallas = [o for o in bpy.data.objects if o.type == "MESH"]
    for m in mallas:
        bpy.context.view_layer.objects.active = m
        for mod in list(m.modifiers):
            if mod.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=mod.name)
        m.parent = None
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for m in mallas:
        m.select_set(True)
    bpy.context.view_layer.objects.active = mallas[0]
    if len(mallas) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    if up == "Y":
        obj.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def normalizar(obj, altura):
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    s = altura / (mx.z - mn.z)
    centro = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for v in obj.data.vertices:
        v.co = (obj.matrix_world @ v.co - centro) * s
    obj.matrix_world.identity()


def decimar(obj, tris_objetivo):
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris <= tris_objetivo:
        return tris
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = tris_objetivo / tris
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def imagen_base(mat):
    """Textura conectada al color base del material (o la primera imagen que encuentre)."""
    if not mat or not mat.use_nodes:
        return None
    imgs = [n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
    for n in imgs:
        for link in n.outputs["Color"].links:
            if link.to_socket.name in ("Base Color", "Color"):
                return n.image
    return imgs[0].image if imgs else None


def kmeans(cols, k, iters=20):
    rng = np.random.default_rng(0)
    centros = cols[rng.choice(len(cols), size=min(k, len(cols)), replace=False)]
    for _ in range(iters):
        d = ((cols[:, None, :] - centros[None, :, :]) ** 2).sum(-1)
        idx = d.argmin(1)
        for j in range(len(centros)):
            if (idx == j).any():
                centros[j] = cols[idx == j].mean(0)
    return centros, idx


def suavizar(me, idx, pasadas=2):
    """Cada cara toma el color mayoritario de sus vecinas si queda aislada (saca manchitas)."""
    vecinas = [[] for _ in me.polygons]
    por_arista = {}
    for p in me.polygons:
        for ek in p.edge_keys:
            por_arista.setdefault(ek, []).append(p.index)
    for caras in por_arista.values():
        for a in caras:
            vecinas[a].extend(c for c in caras if c != a)
    idx = idx.copy()
    for _ in range(pasadas):
        nuevo = idx.copy()
        for i, vs in enumerate(vecinas):
            if not vs:
                continue
            labels, cuenta = np.unique(idx[vs], return_counts=True)
            mayor = labels[cuenta.argmax()]
            if mayor != idx[i] and cuenta.max() > len(vs) / 2:
                nuevo[i] = mayor
        idx = nuevo
    return idx


def paleta_plana(obj, n_colores):
    """Color por cara muestreado de la textura y cuantizado a una paleta chica."""
    me = obj.data
    uv = me.uv_layers.active
    cache = {}
    cols = []
    for p in me.polygons:
        mat = obj.material_slots[p.material_index].material if obj.material_slots else None
        img = imagen_base(mat)
        if img is None or uv is None:
            cols.append((0.7, 0.7, 0.7))
            continue
        if img.name not in cache:
            w, h = img.size
            cache[img.name] = (np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4), w, h)
        px, w, h = cache[img.name]
        # mediana de centro + esquinas (un solo punto cae en bordes del atlas y mancha)
        uvs = [uv.data[i].uv for i in p.loop_indices]
        cu = sum(c.x for c in uvs) / len(uvs)
        cv = sum(c.y for c in uvs) / len(uvs)
        puntos = [(cu, cv)] + [((c.x + cu) / 2, (c.y + cv) / 2) for c in uvs]
        muestras = [px[int((v % 1.0) * (h - 1)), int((u % 1.0) * (w - 1)), :3] for u, v in puntos]
        cols.append(tuple(np.median(np.array(muestras), axis=0)))
    cols = np.array(cols, dtype=np.float32)
    centros, idx = kmeans(cols, n_colores)
    idx = suavizar(me, idx)
    attr = me.color_attributes.new("Paleta", "BYTE_COLOR", "CORNER")
    # los píxeles de la textura vienen en sRGB y el atributo de color espera lineal
    lineal = np.where(centros <= 0.04045, centros / 12.92, ((centros + 0.055) / 1.055) ** 2.4)
    for p, j in zip(me.polygons, idx):
        c = (*lineal[j], 1.0)
        for li in p.loop_indices:
            attr.data[li].color = c
    me.color_attributes.active_color = attr
    return centros


def material_toon():
    mat = bpy.data.materials.new("Toon")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Paleta"
    mult = nt.nodes.new("ShaderNodeMixRGB")
    mult.blend_type = "MULTIPLY"
    mult.inputs[0].default_value = 1.0
    emis = nt.nodes.new("ShaderNodeEmission")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (TONOS_TOON[0],) * 3 + (1,)
    els[1].position, els[1].color = 0.25, (TONOS_TOON[1],) * 3 + (1,)
    e = els.new(0.6)
    e.color = (TONOS_TOON[2],) * 3 + (1,)
    nt.links.new(diff.outputs[0], s2r.inputs[0])
    nt.links.new(s2r.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], mult.inputs[1])
    nt.links.new(attr.outputs[0], mult.inputs[2])
    nt.links.new(mult.outputs[0], emis.inputs[0])
    nt.links.new(emis.outputs[0], out.inputs[0])
    return mat


def material_contorno():
    mat = bpy.data.materials.new("Contorno")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    emis = nt.nodes.new("ShaderNodeEmission")
    emis.inputs[0].default_value = COLOR_CONTORNO
    nt.links.new(emis.outputs[0], out.inputs[0])
    mat.use_backface_culling = True
    return mat


def aplicar_estilo(obj):
    obj.data.materials.clear()
    obj.data.materials.append(material_toon())
    obj.data.materials.append(material_contorno())
    for p in obj.data.polygons:
        p.material_index = 0
    for p in obj.data.polygons:
        p.use_smooth = False
    if PIXEL_ART:
        return
    sol = obj.modifiers.new("Contorno", "SOLIDIFY")
    sol.thickness = GROSOR_CONTORNO
    sol.offset = 1.0
    sol.use_flip_normals = True
    sol.use_rim = False
    sol.material_offset = 1


def escena_render():
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.film_transparent = True
    if PIXEL_ART:
        sc.render.filter_size = 0.0
        if hasattr(sc, "eevee"):
            for attr in ("taa_render_samples", "taa_samples"):
                if hasattr(sc.eevee, attr):
                    setattr(sc.eevee, attr, 1)
    sc.render.resolution_x = sc.render.resolution_y = RESOLUCION
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.25
    sc.world = world
    sun = bpy.data.objects.new("Sol", bpy.data.lights.new("Sol", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = CAMARA_ORTHO
    el = math.radians(CAMARA_ELEVACION)
    dist = 10
    cam.location = (0, -dist * math.cos(el), dist * math.sin(el) + 0.9)
    cam.rotation_euler = (math.radians(90) - el, 0, 0)
    sc.collection.objects.link(cam)
    sc.camera = cam


def renderizar(obj, nombre, salida):
    os.makedirs(salida, exist_ok=True)
    rutas = []
    for d in range(DIRECCIONES):
        obj.rotation_euler = (0, 0, math.radians(360 / DIRECCIONES * d))
        ruta = os.path.join(salida, f"{nombre}_dir{d}.png")
        bpy.context.scene.render.filepath = ruta
        bpy.ops.render.render(write_still=True)
        if PIXEL_ART:
            pixelar(ruta)
        rutas.append(ruta)
    return rutas


def leer(ruta):
    im = bpy.data.images.load(ruta, check_existing=False)
    w, h = im.size
    px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(im)
    return px


def guardar(px, ruta):
    h, w, _ = px.shape
    im = bpy.data.images.new("tmp", w, h, alpha=True)
    im.pixels = px.ravel()
    im.filepath_raw = ruta
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def pixelar(ruta):
    """Alpha duro + contorno de 1 px (4-vecinos) alrededor de la silueta."""
    px = leer(ruta)
    solido = px[..., 3] > 0.5
    px[..., 3] = solido.astype(np.float32)
    borde = np.zeros_like(solido)
    borde[1:, :] |= solido[:-1, :]
    borde[:-1, :] |= solido[1:, :]
    borde[:, 1:] |= solido[:, :-1]
    borde[:, :-1] |= solido[:, 1:]
    borde &= ~solido
    px[borde] = COLOR_CONTORNO
    guardar(px, ruta)


def hoja(rutas, destino):
    """Une las direcciones en una tira horizontal (sprite sheet)."""
    imgs = [bpy.data.images.load(r) for r in rutas]
    w, h = imgs[0].size
    sheet = np.zeros((h, w * len(imgs), 4), dtype=np.float32)
    for i, im in enumerate(imgs):
        sheet[:, i * w:(i + 1) * w] = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
    out = bpy.data.images.new("sheet", w * len(imgs), h, alpha=True)
    out.pixels = sheet.ravel()
    out.filepath_raw = destino
    out.file_format = "PNG"
    out.save()
    if PREVIEW_ESCALA > 1:
        grande = sheet.reshape(h, w * len(imgs), 4).repeat(PREVIEW_ESCALA, 0).repeat(PREVIEW_ESCALA, 1)
        guardar(grande, destino.replace(".png", f"_x{PREVIEW_ESCALA}.png"))


def main():
    modelo, nombre, salida, etapa = args()
    limpiar_escena()
    importar(modelo)
    asignar_texturas(modelo)
    borrar_contorno_original()
    posar()
    obj = unificar_malla()
    normalizar(obj, ALTURA_POR_ETAPA[etapa])
    tris = decimar(obj, TRIS_POR_ETAPA[etapa])
    paleta = paleta_plana(obj, COLORES_PALETA)
    aplicar_estilo(obj)
    escena_render()
    rutas = renderizar(obj, nombre, salida)
    hoja(rutas, os.path.join(salida, f"{nombre}_sheet.png"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(salida, f"{nombre}_estilizado.blend"))
    print(f"[dijimones] {nombre}: {tris} tris, paleta {len(paleta)} colores -> {salida}")


if __name__ == "__main__":
    main()
