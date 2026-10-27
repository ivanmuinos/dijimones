"""Arma game/assets/sprites/digimon/preview.html con todos los Digimon renderizados, agrupados por temporada.

Uso (desde la raíz del proyecto):
  python3 blender/scripts/build_preview.py
"""
import csv
import glob
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPRITES = os.path.join(RAIZ, "game", "assets", "sprites", "digimon")
ZOOM = 3
ORDEN_ETAPAS = ["In-Training", "Rookie", "Champion", "Ultimate", "Mega"]


def roster():
    info = {}
    with open(os.path.join(RAIZ, "data", "roster.csv")) as fh:
        for r in csv.DictReader(fh):
            info.setdefault(r["nombre"], r)
    return info


def main():
    info = roster()
    temporadas = list(dict.fromkeys(r["temporada"] for r in info.values()))
    mans = [json.load(open(f)) for f in glob.glob(os.path.join(SPRITES, "*", "*.json"))]
    grupos = {}
    for m in mans:
        t = info.get(m["nombre"], {}).get("temporada", "Otros")
        grupos.setdefault(t, []).append(m)
    css, secciones = [], []
    for t in temporadas + ["Otros"]:
        if t not in grupos:
            continue
        filas = []
        for m in sorted(grupos[t], key=lambda m: (info.get(m["nombre"], {}).get("linea", ""),
                                                  ORDEN_ETAPAS.index(m["etapa"]) if m["etapa"] in ORDEN_ETAPAS else 9)):
            n, s = m["nombre"], m["tamano_frame"]
            celdas = []
            for a, v in m["animaciones"].items():
                k = f"{n}_{a}".replace(" ", "_").replace("(", "").replace(")", "")
                f, dur = v["frames"], v["frames"] / v["fps"]
                css.append(f".{k}{{background:url('{n}/{n}_{a}.png');animation:{k} {dur:.2f}s steps({f}) infinite}}"
                           f"@keyframes {k}{{to{{background-position:-{f * s}px 0}}}}")
                celdas.append(f'<figure><div class="spr {k}"></div><figcaption>{a}</figcaption></figure>')
            r = info.get(n, {})
            meta = " · ".join(x for x in (m["etapa"], r.get("atributo", ""), r.get("rol", "")) if x)
            filas.append(f'<div class="row"><div class="name">{n}<small>{meta}</small></div>{"".join(celdas)}</div>')
        secciones.append(f"<h2>{t} <small>({len(grupos[t])})</small></h2>" + "".join(filas))
    s = mans[0]["tamano_frame"] if mans else 96
    html = f"""<!doctype html><html lang="es"><meta charset="utf-8"><title>Dijimones — preview de sprites</title>
<style>body{{background:#2d5a36;color:#eee;font:14px system-ui;margin:24px}}
h2{{border-bottom:1px solid #fff4;padding-bottom:4px;margin-top:32px}}small{{opacity:.6;font-weight:400}}
.row{{display:flex;align-items:end;gap:4px;margin-bottom:4px}}.name{{width:150px;font-weight:600;display:flex;flex-direction:column}}
figure{{margin:0;text-align:center;font-size:11px}}
.spr{{width:{s}px;height:{s}px;zoom:{ZOOM};image-rendering:pixelated}}
.flip .spr{{transform:scaleX(-1)}}
{''.join(css)}</style>
<h1>Dijimones — sprites <small>({len(mans)} Digimon · pixel art {s}px · x{ZOOM})</small></h1>
<label><input type="checkbox" onchange="document.body.classList.toggle('flip',this.checked)"> espejar (mirando a la izquierda)</label>
{''.join(secciones)}</html>"""
    with open(os.path.join(SPRITES, "preview.html"), "w") as fh:
        fh.write(html)
    print(f"preview.html con {len(mans)} Digimon")


if __name__ == "__main__":
    main()
