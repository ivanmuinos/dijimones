# data/

## roster.csv

Planilla maestra del roster (ver PRD 9.3). Es la fuente de verdad: de acá se generan los `.tres` de Godot.

| Columna | Valores |
|---|---|
| `nombre` | Nombre en inglés (el de Wikimon) |
| `etapa` | In-Training, Rookie, Champion, Ultimate, Mega, Armor, Human Spirit, Beast Spirit, Fusion, DigiXros… |
| `temporada` | Temporada / Season Pack (PRD 5.5) |
| `rol` | `partner`, `partner-alt`, `partner-armor`, `partner-dna`, `jefe`, `enemigo-escaneable` |
| `linea` | Partner al que pertenece la forma |
| `evoluciona_de` / `evoluciona_a` | Línea principal (las rutas alternativas van en `notas`) |
| `mvp` | `inicial`, `desbloqueable`, `sí` o vacío |
| `atributo` | Atributo principal (Vaccine, Data, Virus, Free, Variable), el primero que lista Wikimon |
| `atributos_otros` | Otros atributos que tiene en distintos medios |
| `familia` | Familia de Cyber Sleuth si existe; si no, la primera de Wikimon. **Provisoria**: en el juego define el kit de ataques y se puede reasignar |
| `wikimon` / `nivel_wikimon` | Título de la página en Wikimon (suele ser el nombre japonés) y niveles en terminología japonesa |
| `fuente_modelo_candidata` | Juegos con modelo en The Models Resource (relevado 2026-10-27, ver `models_availability.txt`) |
| `estado_modelo` | `disponible`, `no existe` (no hay modelo, hay que hacerlo o buscar otra fuente), `sin verificar` |

## Pendientes

1. **29 Digimon sin modelo** (`estado_modelo = no existe`): sobre todo DigiXros de Shoutmon, Xros Wars, Ghost Game, algunos de Frontier y Royal Knights. Buscar en otras fuentes o modelarlos.
2. Revisar a mano las variantes que se asignaron al modelo base: `Agumon (Savers)` y `Greymon (Xros)` usan el resultado de Agumon / Greymon común.
3. 18 sin atributo (Wikimon usa otro formato en esas páginas): completar a mano.
4. Verificar líneas de Ghost Game, Beatbreak y los Mega de Hawkmon/Armadillomon.
5. Agregar las especies escaneables de las demás regiones (hay ~680 especies con modelo entre los 7 juegos).
