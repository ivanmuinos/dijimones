# blender/

Pipeline de estética unificada (PRD 9.3): modelo base → mismo estilo → sprites.

```
blender -b -P blender/scripts/stylize_render.py -- <modelo.fbx> <Nombre> <salida_dir> --etapa Rookie
```

Genera en `<salida_dir>`: `<Nombre>_dir0..7.png` (8 direcciones), `<Nombre>_sheet.png`, `<Nombre>_sheet_x4.png` (ampliada para mirar) y `<Nombre>_estilizado.blend`. Con `PIXEL_ART = True` renderiza a 96 px sin antialiasing y con contorno de 1 px.

Los parámetros de estilo (altura y polígonos por etapa, colores de paleta, tonos toon, grosor de contorno, cámara) están arriba de todo en el script y son los mismos para todos los Digimon.

## Notas sobre los modelos de Cyber Sleuth (`source/raw/`)
- Usan **Y como arriba**: el script los rota.
- Traen su **propio contorno** como una malla sin UVs: el script la borra y usa el nuestro.
- El material **no trae la textura conectada**: se asigna `chrNNNa01.png` por nombre.
- Traen **las animaciones del juego** (`_bn01` idle, `_br01` correr, `_ba01` ataque, `_bd01` daño, `_bv01` victoria, …). Por ahora se usa el primer frame del idle como pose.
- `source/raw/` son assets rippeados: base de trabajo, **no se distribuyen** con el juego.

## Animaciones

```
blender -b -P blender/scripts/render_anims.py -- <modelo.fbx> <Nombre> game/assets/sprites/digimon/<Nombre> --etapa Rookie
```

Mismo estilo que `stylize_render.py`, pero conserva el esqueleto. Renderiza **una dirección** (casi de perfil, mirando a la derecha; Godot la espeja) y estas animaciones: `idle`, `correr`, `ataque`, `golpe`, `victoria` (a 10 fps, máx. 12 frames). Genera una tira PNG por animación y `<Nombre>.json` con frames/fps/loop.

Ojo: las acciones del FBX animan la transformación del propio armature, por eso el script lo mete en un padre vacío (`Raiz`) y gira/escala el padre.

Para mirarlas: `game/assets/sprites/digimon/preview.html`.

## Lote completo

```
python3 blender/scripts/process_all.py -j 4      # procesa todo blender/source/raw/<Nombre>/ (saltea los ya hechos; --rehacer, --solo A,B)
python3 blender/scripts/build_preview.py         # regenera preview.html agrupado por temporada
blender -b -P blender/tools/montage.py -- game/assets/sprites/digimon /tmp/montage.png   # grilla de control
```

- Etapa: la de `data/roster.csv`; si está vacía (jefes/enemigos), el primer nivel de Wikimon.
- Si una carpeta trae varios FBX (variantes), usa el de número más bajo que tenga textura.
- Si un modelo no trae una animación, se genera **procedural** (se mueve el modelo entero) y el manifiesto lo marca con `"procedural": true`. Hoy: Lopmon y Seadramon.

## Pendientes
- GeoGreymon vino solo en `.dae` (Blender 5 no importa Collada): buscar otra fuente.
- Los Digimon muy largos (Seadramon, Leviamon, Examon, KendoGarurumon) se salen del cuadro de 96 px: escalar por la dimensión mayor o agrandar el cuadro para esos.
- Agumon (Savers) y Greymon (Xros) usan el modelo del Agumon/Greymon clásico.
