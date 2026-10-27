"""Grilla con el primer frame del idle de todos los Digimon (control de calidad).
Uso: blender -b -P blender/tools/montage.py -- <sprites_dir> <salida.png>"""
import bpy, glob, os, sys
import numpy as np
src, out = sys.argv[sys.argv.index("--") + 1:][:2]
files = sorted(glob.glob(os.path.join(src, "*", "*_idle.png")))
tiles = []
for f in files:
    im = bpy.data.images.load(f); w, h = im.size
    tiles.append(np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :h])
cols = 14; s = tiles[0].shape[0]; rows = (len(tiles) + cols - 1) // cols
canvas = np.zeros((rows * s, cols * s, 4), dtype=np.float32); canvas[..., :3] = (0.18, 0.35, 0.21); canvas[..., 3] = 1
for i, t in enumerate(tiles):
    r, c = rows - 1 - i // cols, i % cols
    a = t[..., 3:4]; cell = canvas[r*s:(r+1)*s, c*s:(c+1)*s]
    cell[..., :3] = t[..., :3] * a + cell[..., :3] * (1 - a)
canvas = canvas.repeat(2, 0).repeat(2, 1)
img = bpy.data.images.new("m", canvas.shape[1], canvas.shape[0]); img.pixels = canvas.ravel()
img.filepath_raw = out; img.file_format = "PNG"; img.save()
print("montage", len(files), [os.path.basename(f)[:-9] for f in files])
