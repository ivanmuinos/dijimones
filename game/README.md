# game/ — Dijimones (Godot 4.7, web)

## Jugar
- **Mover:** WASD o flechas. Los ataques son automáticos.
- **Level up:** aparecen 3 cartas a la derecha **sin pausar**; elegí con **1/2/3** o clic (5 s, invulnerable mientras tanto).
- **Espacio:** saltar (sube escalones y esquiva golpes al piso). **R:** especial (y reintentar al terminar). **Q/E o rueda:** zoom. **M:** música. **Esc:** menú.

## Correr
```
godot --path game                         # editor / jugar desde Godot
godot --headless --path game --fixed-fps 60 --quit-after 60000 -- --autotest   # simula una run con un bot e imprime el estado por minuto
```

## Exportar a web
```
cd game && godot --headless --path . --export-release "Web" ../build/web/index.html
cd ../build/web && python3 -m http.server 8060   # abrir http://127.0.0.1:8060
```
- Renderer Compatibility (WebGL 2), sin threads: corre en itch.io sin headers especiales.
- `editor/export/convert_text_resources_to_binary=false` en `project.godot`: con la conversión a binario el export perdía el `PackedStringArray` de `CharacterData.line` (el jugador quedaba sin sprite).

## Publicar en Cloudflare Pages
```
cd game && godot --headless --path . --export-release "Web" ../build/web/index.html
cd .. && python3 tools/prepare_cloudflare.py          # parte index.wasm (>25 MiB, límite de Pages)
npx wrangler login                                     # una vez
npx wrangler pages deploy build/cloudflare --project-name dijimones
```

## Música
Temas chiptune **originales** generados con `python3 tools/make_music.py` (no se usan temas oficiales de Digimon).

## Estructura
| Carpeta | Qué hay |
|---|---|
| `data/` | Contenido en `.tres`: personajes, armas, chips, enemigos, mapas (oleadas y jefes) |
| `scripts/data/` | Clases de los Resources (`CharacterData`, `WeaponData`, `EnemyData`, `StageData`…) |
| `scripts/core/` | Simulación: `main.gd` corre todo en orden fijo por frame; enemigos, proyectiles y gemas son arrays dibujados por un solo nodo (PRD 8.3) |
| `scripts/autoload/digimon_db.gd` | Carga los sprites de `assets/sprites/digimon/<Especie>/` a partir de su `.json` |
| `scripts/ui/` | HUD y menú de level up |
| `scripts/view/paper_view.gd` | Dibuja la simulación como mundo 3D de papel (estilo Paper Mario): MultiMesh por especie, piso, decorados, sombras |
| `shaders/` | `paper_sprite` (recorte con borde blanco y giro de hoja), `paper_ground` (piso + mar), `paper_prop` (decorados por SDF), `paper_flat` (sombras, gemas, proyectiles, aura) |

## Estado (vertical slice)
- Koromon → Agumon (nv 5) → Greymon (nv 15), con onda expansiva al digievolucionar.
- 3 armas (Pepper Breath, Boom Bubble, Fire Wall) y 8 chips.
- File Island: 10 tipos de enemigo en 7 oleadas + Ogremon (5:00) y Leomon (10:00). Run de 15 min.
- Balance sin ajustar: el bot de `--autotest` llega a ~5:30. Falta playtest con personas.
- Look de papel 2.5D: Playa de File Island con mar como borde, palmeras, rocas, caracolas, flores y fila de cabinas de teléfono.
- Pendiente del MVP: meta-progresión, Digi-Eggs, mapa del mundo, online co-op, cloud save.
