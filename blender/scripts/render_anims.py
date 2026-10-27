"""Dijimones: renderiza las animaciones de un modelo base a sprite sheets con la estética unificada.

Uso:
  blender -b -P blender/scripts/render_anims.py -- <modelo.fbx> <Nombre> <salida_dir> [--etapa Rookie]

Usa el mismo estilo que stylize_render.py, pero conserva el esqueleto para poder posar cada frame.
Renderiza una sola dirección (3/4 mirando a la derecha); Godot la espeja para ir a la izquierda.

Salida en <salida_dir>:
  <Nombre>_<anim>.png      tira horizontal de frames de RESOLUCION x RESOLUCION
  <Nombre>_<anim>_x4.png   copia ampliada para mirar
  <Nombre>.json            manifiesto: frames y fps de cada animación
"""
import json
import math
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stylize_render as sr  # noqa: E402

# animación del juego -> sufijo de la acción en los modelos de Cyber Sleuth
ANIMACIONES = {
    "idle": "_bn01",
    "correr": "_br01",
    "ataque": "_ba01",
    "golpe": "_bd01",
    "victoria": "_bv01",
}
FPS_ORIGEN = 30
FPS_SPRITE = 10          # se toma 1 de cada 3 frames
MAX_FRAMES = 12
DIRECCION = 70.0         # grados: casi de perfil mirando a la derecha (Godot espeja para la izquierda)


def preparar_malla():
    """Une las mallas manteniendo el esqueleto (las mallas comparten el mismo armature)."""
    mallas = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for m in mallas:
        m.select_set(True)
    bpy.context.view_layer.objects.active = mallas[0]
    if len(mallas) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def decimar_base(obj, tris_objetivo):
    """Decima la malla base (antes del armature) para que la topología sea igual en todos los frames."""
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris <= tris_objetivo:
        return tris
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = tris_objetivo / tris
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def accion(sufijo):
    return next((a for a in bpy.data.actions if a.name.endswith(sufijo)), None)


def usar_accion(arm, act):
    arm.animation_data_create()
    arm.animation_data.action = act
    if getattr(act, "slots", None) and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    arm.data.pose_position = "POSE"


def limites(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    pts = [ev.matrix_world @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def normalizar_esqueleto(arm, obj, altura):
    """Mete el esqueleto en un padre vacío y transforma el padre: las acciones del FBX
    animan la transformación del propio armature, así que girarlo directamente no sirve.
    Rota (Y arriba -> Z arriba, y gira a DIRECCION), escala y apoya en el piso con el primer frame del idle."""
    raiz = bpy.data.objects.new("Raiz", None)
    bpy.context.scene.collection.objects.link(raiz)
    arm.parent = raiz
    raiz.rotation_euler = (math.radians(90), 0, math.radians(DIRECCION))
    bpy.context.scene.frame_set(1)
    mn, mx = limites(obj)
    s = altura / (mx.z - mn.z)
    raiz.scale = (s, s, s)
    bpy.context.scene.frame_set(1)
    mn, mx = limites(obj)
    raiz.location = (-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)


def frames_de(act):
    ini, fin = int(act.frame_range[0]), int(act.frame_range[1])
    paso = max(1, FPS_ORIGEN // FPS_SPRITE)
    frames = list(range(ini, fin, paso))
    if len(frames) > MAX_FRAMES:
        idx = np.linspace(0, len(frames) - 1, MAX_FRAMES).round().astype(int)
        frames = [frames[i] for i in idx]
    return frames


# Respaldo para modelos sin la animación: se mueve el modelo entero.
# Cada frame: (desplazamiento horizontal, vertical) en fracción de la altura, inclinación en grados (+ = hacia adelante)
PROCEDURALES = {
    "idle": [(0, 0, 0), (0, 0.02, 0), (0, 0.03, 0), (0, 0.02, 0)],
    "correr": [(0, 0, 8), (0, 0.06, 8), (0, 0.1, 8), (0, 0.06, 8), (0, 0, 8), (0, 0.03, 8)],
    "ataque": [(0, 0, 0), (-0.05, 0, -5), (-0.08, 0, -8), (0.15, 0.02, 12), (0.1, 0, 6), (0, 0, 0)],
    "golpe": [(0, 0, 0), (-0.1, 0, -12), (-0.06, 0, -6), (0, 0, 0)],
    "victoria": [(0, 0, 0), (0, 0.15, 0), (0, 0.25, 0), (0, 0.15, 0), (0, 0, 0), (0, 0, 0)],
}


def pose_base(arm, modelo):
    """Pose para los modelos sin idle: la acción con el mismo chrNNN que el FBX (pose del juego) o la de reposo."""
    m = re.search(r"chr\d+", os.path.basename(modelo))
    act = next((a for a in bpy.data.actions if m and a.name.split("|")[-1] == m.group(0)), None)
    if act:
        usar_accion(arm, act)
    else:
        arm.data.pose_position = "REST"


def tira_de(salida, pasos):
    """Renderiza un frame por cada paso (función que deja la escena lista) y devuelve la tira."""
    tiras = []
    tmp = os.path.join(salida, "_tmp.png")
    sc = bpy.context.scene
    for paso in pasos:
        paso()
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        if sr.PIXEL_ART:
            sr.pixelar(tmp)
        tiras.append(sr.leer(tmp))
    os.remove(tmp)
    return np.concatenate(tiras, axis=1)


def guardar_tira(tira, salida, nombre, anim):
    destino = os.path.join(salida, f"{nombre}_{anim}.png")
    sr.guardar(tira, destino)
    if sr.PREVIEW_ESCALA > 1:
        k = sr.PREVIEW_ESCALA
        sr.guardar(tira.repeat(k, 0).repeat(k, 1), destino.replace(".png", f"_x{k}.png"))


def renderizar_anim(arm, nombre, anim, act, salida):
    usar_accion(arm, act)
    frames = frames_de(act)
    tira = tira_de(salida, [lambda f=f: bpy.context.scene.frame_set(f) for f in frames])
    guardar_tira(tira, salida, nombre, anim)
    return len(frames)


def renderizar_procedural(proc, nombre, anim, salida, altura):
    def paso(dx, dz, inclinacion):
        def aplicar():
            proc.location = (dx * altura, 0, dz * altura)
            proc.rotation_euler = (0, math.radians(inclinacion), 0)
            bpy.context.view_layer.update()
        return aplicar
    tira = tira_de(salida, [paso(*p) for p in PROCEDURALES[anim]])
    proc.location, proc.rotation_euler = (0, 0, 0), (0, 0, 0)
    guardar_tira(tira, salida, nombre, anim)
    return len(PROCEDURALES[anim])


def main():
    modelo, nombre, salida, etapa = sr.args()
    os.makedirs(salida, exist_ok=True)
    sr.limpiar_escena()
    sr.importar(modelo)
    sr.asignar_texturas(modelo)
    sr.borrar_contorno_original()
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    obj = preparar_malla()
    tris = decimar_base(obj, sr.TRIS_POR_ETAPA[etapa])
    sr.paleta_plana(obj, sr.COLORES_PALETA)
    sr.aplicar_estilo(obj)
    idle = accion(ANIMACIONES["idle"])
    if idle:
        usar_accion(arm, idle)
    else:
        pose_base(arm, modelo)
    altura = sr.ALTURA_POR_ETAPA[etapa]
    normalizar_esqueleto(arm, obj, altura)
    # padre extra para las animaciones procedurales (la cámara mira a +Y: girar en Y inclina en pantalla)
    proc = bpy.data.objects.new("Procedural", None)
    bpy.context.scene.collection.objects.link(proc)
    arm.parent.parent = proc
    sr.escena_render()
    manifiesto = {"nombre": nombre, "etapa": etapa, "tamano_frame": sr.RESOLUCION, "animaciones": {}}
    for anim, sufijo in ANIMACIONES.items():
        act = accion(sufijo)
        if act is None:
            # sin la animación: pose fija + movimiento del modelo entero
            if idle:
                usar_accion(arm, idle)
                bpy.context.scene.frame_set(1)
            else:
                pose_base(arm, modelo)
            n = renderizar_procedural(proc, nombre, anim, salida, altura)
        else:
            n = renderizar_anim(arm, nombre, anim, act, salida)
        manifiesto["animaciones"][anim] = {"frames": n, "fps": FPS_SPRITE, "loop": anim in ("idle", "correr"),
                                           "procedural": act is None}
    with open(os.path.join(salida, f"{nombre}.json"), "w") as fh:
        json.dump(manifiesto, fh, indent=2, ensure_ascii=False)
    resumen = ", ".join(f"{k} {v['frames']}f" + (" (proc)" if v["procedural"] else "")
                        for k, v in manifiesto["animaciones"].items())
    print(f"[dijimones] {nombre}: {tris} tris | {resumen} -> {salida}")


if __name__ == "__main__":
    main()
