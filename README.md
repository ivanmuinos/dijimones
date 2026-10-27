# Dijimones

Fan game **gratis y no oficial** estilo *Vampire Survivors* con Digimon, para navegador. Godot 4 (web) + Blender.
Mundo de papel 2.5D estilo *Paper Mario*, digievolución en plena partida, mini jefes y (próximamente) co-op online.

> Digimon es propiedad de Bandai Namco / Toei Animation / Akiyoshi Hongo. Proyecto de fans, sin fines de lucro y sin afiliación.

**Jugar:** https://dijimones.pages.dev/

## Qué hay en el repo
| Carpeta | Qué es |
|---|---|
| `PRD.md` | Documento de producto: visión, mecánicas, roster, progresión, arquitectura, mapas, roadmap |
| `game/` | Proyecto de Godot 4.7 (ver `game/README.md`: controles, estructura, export web y deploy) |
| `blender/` | Pipeline modelo 3D → sprites pixel art con estética unificada (ver `blender/README.md`) |
| `data/` | `roster.csv` (todos los Digimon planeados por temporada, con datos de Wikimon y disponibilidad de modelos) |
| `tools/` | Música chiptune original (`make_music.py`) y preparación del build para Cloudflare |

## Requisitos
- Godot 4.7 (con plantillas de export web)
- Blender 5.2 (solo para generar sprites nuevos)
- Python 3 y Node (para `wrangler` si se publica en Cloudflare)

## Assets
Los sprites de `game/assets/sprites/digimon/` ya están generados. Los **modelos 3D originales no están en el repo**
(`blender/source/raw/` está en `.gitignore`): se bajan de The Models Resource (Digimon Story Cyber Sleuth: Complete
Edition). La lista de cada Digimon con su archivo está en `data/cs_zips.txt` y `data/models_availability.txt`.
Con los modelos en `blender/source/raw/<Nombre>/`, `python3 blender/scripts/process_all.py` regenera todo.

## Correr
```
godot --path game                      # abrir en el editor y darle Play
```

## Deploy automático
Cada push a `main` corre `.github/workflows/deploy.yml`: exporta con Godot, parte el `.wasm` y publica en
Cloudflare Pages (https://dijimones.pages.dev). Necesita los secrets `CLOUDFLARE_API_TOKEN` (permiso
"Cloudflare Pages: Edit") y `CLOUDFLARE_ACCOUNT_ID` en el repo.
