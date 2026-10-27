"""Lista las acciones de un FBX. Uso: blender -b -P blender/tools/list_actions.py -- <modelo.fbx>"""
import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=sys.argv[sys.argv.index("--") + 1])
print("ACTIONS", [a.name.split("|")[-1] for a in bpy.data.actions])
