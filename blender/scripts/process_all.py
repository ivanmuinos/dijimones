"""Procesa en lote todos los modelos de blender/source/raw/<Nombre>/ con render_anims.py.

Uso (desde la raíz del proyecto):
  python3 blender/scripts/process_all.py [--solo Agumon,Gabumon] [--rehacer] [-j 3]

- La etapa de cada Digimon sale de data/roster.csv (Armor/Hybrid/etc. se mapean a la etapa equivalente).
- Saltea los que ya tienen <Nombre>.json salvo con --rehacer.
- Deja el log de errores en blender/process_all.log.
"""
import argparse
import csv
import glob
import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(RAIZ, "blender", "source", "raw")
SALIDA = os.path.join(RAIZ, "game", "assets", "sprites", "digimon")
SCRIPT = os.path.join(RAIZ, "blender", "scripts", "render_anims.py")
LOG = os.path.join(RAIZ, "blender", "process_all.log")
ETAPAS = {"In-Training": "In-Training", "Rookie": "Rookie", "Champion": "Champion", "Ultimate": "Ultimate",
          "Mega": "Mega", "Armor": "Champion", "Human Spirit": "Champion", "Beast Spirit": "Ultimate",
          "Fusion": "Mega", "Ancient/Unified": "Mega", "DigiXros": "Ultimate"}


# niveles de Wikimon (terminología japonesa) -> etapa
NIVELES_WIKIMON = {"Baby I": "In-Training", "Baby II": "In-Training", "Child": "Rookie", "Adult": "Champion",
                   "Armor": "Champion", "Hybrid": "Champion", "Perfect": "Ultimate", "Ultimate": "Mega",
                   "Super Ultimate": "Mega"}


def etapas_roster():
    """Etapa de la planilla; si está vacía (jefes, enemigos), el primer nivel que lista Wikimon."""
    out = {}
    with open(os.path.join(RAIZ, "data", "roster.csv")) as fh:
        for r in csv.DictReader(fh):
            etapa = ETAPAS.get(r["etapa"])
            if not etapa:
                nivel = r.get("nivel_wikimon", "").split("/")[0]
                etapa = NIVELES_WIKIMON.get(nivel, "Champion" if r["rol"] == "jefe" else "Rookie")
            out.setdefault(r["nombre"], etapa)
    return out


def modelo_de(carpeta):
    """El FBX de número más bajo que tenga su textura (las carpetas con varios traen variantes)."""
    fbx = sorted(glob.glob(os.path.join(carpeta, "**", "*.fbx"), recursive=True))
    con_textura = [f for f in fbx if tiene_textura(f)]
    return (con_textura or fbx or [None])[0]


def tiene_textura(fbx):
    m = re.search(r"chr\d+", os.path.basename(fbx))
    return bool(m) and any(os.path.exists(os.path.join(os.path.dirname(fbx), m.group(0) + s))
                           for s in ("a01.png", "a01a.png"))


def procesar(nombre, etapa):
    fbx = modelo_de(os.path.join(RAW, nombre))
    if not fbx:
        return nombre, "sin .fbx"
    cmd = ["blender", "-b", "-P", SCRIPT, "--", fbx, nombre, os.path.join(SALIDA, nombre), "--etapa", etapa]
    r = subprocess.run(cmd, capture_output=True, text=True)
    ok = [l for l in r.stdout.splitlines() if l.startswith("[dijimones]")]
    if r.returncode != 0 or not os.path.exists(os.path.join(SALIDA, nombre, f"{nombre}.json")):
        cola = "\n".join((r.stdout + r.stderr).splitlines()[-15:])
        return nombre, f"ERROR\n{cola}"
    return nombre, ok[-1] if ok else "ok"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--solo", default="")
    ap.add_argument("--rehacer", action="store_true")
    ap.add_argument("-j", type=int, default=3)
    a = ap.parse_args()
    etapas = etapas_roster()
    nombres = sorted(d for d in os.listdir(RAW) if os.path.isdir(os.path.join(RAW, d)))
    if a.solo:
        nombres = [n for n in nombres if n in a.solo.split(",")]
    if not a.rehacer:
        nombres = [n for n in nombres if not os.path.exists(os.path.join(SALIDA, n, f"{n}.json"))]
    print(f"Procesando {len(nombres)} modelos con {a.j} procesos...")
    errores = []
    with ThreadPoolExecutor(a.j) as ex:
        for nombre, res in ex.map(lambda n: procesar(n, etapas.get(n, "Rookie")), nombres):
            print(("✗ " if res.startswith(("ERROR", "sin")) else "✓ ") + (res if not res.startswith("ERROR") else nombre))
            if res.startswith(("ERROR", "sin")):
                errores.append(f"## {nombre}\n{res}\n")
    with open(LOG, "w") as fh:
        fh.write("\n".join(errores) or "sin errores\n")
    print(f"Listo: {len(nombres) - len(errores)} ok, {len(errores)} con error (ver {LOG})")


if __name__ == "__main__":
    main()
