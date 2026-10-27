# PRD — Dijimones

> Clon de *Vampire Survivors* con Digimon · **Gratis**, para navegador · Godot 4 + Blender
> Fecha: 2026-10-27 · Estado: Borrador v0.1

---

## 1. Visión

**Pitch:** Sos un Digimon novato perdido en el Digital World. Hordas de Digimon corruptos te persiguen. Sobreviví 20 minutos, juntá datos (XP), armá tu build y **digievolucioná en plena partida** de Rookie → Champion → Ultimate → Mega. **Online co-op de hasta 4 jugadores en el navegador**: pasás un link a tus amigos y juegan juntos.

**La vuelta de tuerca respecto a Vampire Survivors:** en VS las "evoluciones" son de armas. Acá **evoluciona el personaje**: cada etapa cambia sprite, stats, ataque base y desbloquea slots. Las armas también evolucionan (como en VS), y ciertas combinaciones de arma + etapa habilitan **Digievoluciones alternativas** (ej. Agumon → SkullGreymon si juntás armas "corruptas").

| Aspecto | Definición |
|---|---|
| Plataforma | Web (desktop primero, mobile táctil después). Hosting: itch.io / web propia |
| Modelo de negocio | **Gratis, sin monetización** (sin ads, sin compras, sin donaciones atadas al juego) |
| Público | Fans de Digimon 20–35 años (nostalgia Adventure / World / V-Pet) + fans de survivors-likes |
| Sesión | Runs de 15–20 min, jugables con una mano (solo movimiento) |
| Multijugador | **Online co-op 1–4 jugadores** con código de sala o link (ver 8.6) |
| Referencias | Vampire Survivors, Brotato, Halls of Torment, 20 Minutes Till Dawn, Digimon World 1, V-Pet |
| Estilo visual | Pixel art o sprites pre-renderizados desde Blender, cámara top-down |

---

## 2. Aviso legal (leer antes que todo)

Digimon es propiedad de **Bandai Namco / Toei Animation / Akiyoshi Hongo**. Usar sus personajes, sprites, modelos, nombres o música sin licencia es infracción de copyright y marca, **aunque el juego sea gratis**. Bandai Namco ya bajó fan games y proyectos de fans con DMCA en otras ocasiones.

**Opciones realistas:**

| Opción | Qué implica | Riesgo |
|---|---|---|
| A. Fan game privado | Assets rippeados, solo para vos y amigos, sin publicarlo | Bajo (uso personal) |
| B. Fan game público, no comercial | Publicado en itch.io, sin monetizar, con disclaimer | **Medio/Alto**: te pueden bajar el juego en cualquier momento. El disclaimer no te protege legalmente |
| C. Juego original "digi-like" | Monstruos propios inspirados en el género (como Temtem / Cassette Beasts con Pokémon) | Nulo. **Se puede vender** |

**Decisión:** juego **gratis para navegador** → prototipo privado con la **A** y lanzamiento público con la **B**.

Reglas para bajar el riesgo de la B (no lo elimina: ser gratis no da derecho a usar la IP):
- Cero monetización: sin ads, sin compras, sin Patreon/Ko-fi vinculado al juego.
- No usar el logo oficial de Digimon ni el nombre "Digimon" como título (por eso **Dijimones**).
- Disclaimer visible: fan game no oficial, sin afiliación con Bandai Namco/Toei.
- No redistribuir música oficial; usar música propia o CC0.
- Si llega un DMCA, se baja sin pelear y se migra a la **C**: la arquitectura **data-driven** (sección 8) permite cambiar el roster por monstruos originales cambiando datos y sprites, no código.

---

## 3. Objetivos y métricas

**Objetivos del producto**
1. Run completa y divertida en < 30 s desde que abrís el link (sin instalación, carga < 15 MB).
2. Sensación de "power fantasy" de VS: pantalla llena de enemigos y efectos a 60 FPS.
3. La digievolución en partida como momento "wow" (pausa, animación, cambio de ataque).

**Métricas (si se publica)**
| Métrica | Objetivo |
|---|---|
| Tiempo de carga inicial | < 10 s en conexión 20 Mbps |
| FPS con 500 enemigos en pantalla | ≥ 60 desktop, ≥ 30 mobile medio |
| % jugadores que completan la 1ª run | > 60 % |
| Retención "una run más" (≥ 3 runs por sesión) | > 40 % |
| Duración media de sesión | > 25 min |

---

## 4. Core loop y mecánicas base

```
Moverse ──► ataques automáticos matan enemigos ──► sueltan Data (XP)
   ▲                                                      │
   │                                                      ▼
Sobrevivir oleadas ◄── elegir 1 de 3 mejoras ◄── subir de nivel
   │
   └─► a los 30 min (o al morir) ► Bits (moneda meta) ► mejoras permanentes
```

**Controles:** solo movimiento (WASD / flechas / stick / joystick táctil virtual). Ataques automáticos. Pausa con Esc (solo en single player).

**Mecánicas base (paridad con VS):**
- Hordas que escalan por minuto (tabla de oleadas por stage).
- XP en forma de "Data fragments" que se atraen con imán.
- Subir de nivel → elegir entre 3 cartas (armas nuevas, mejoras de armas, pasivas). Reroll / skip / banish limitados.
- Máximo **6 armas + 6 pasivas**.
- Cofres que sueltan los jefes → evolución de armas si cumplís requisitos.
- Reloj: a los 30:00 aparece la "Muerte" equivalente → **Apocalymon / Reaper** que te mata.

**Mecánicas propias:**
- **Digievolución al subir de nivel:** In-Training → Rookie (nv 5) → Champion (nv 15) → Ultimate (nv 30) → Mega (nv 50). Cada evolución: +stats, nuevo ataque firma, curación total, onda que limpia la pantalla (ver 5.2).
- **Rutas alternativas:** la build define la evolución (ej. armas de fuego → WarGreymon; armas oscuras → SkullGreymon/BlackWarGreymon).
- **Digivice (ítem activo, post-MVP):** un botón con cooldown (ej. Warp Digivolve temporal 10 s).

---

## 5. Personajes, digievolución y desbloqueos

### 5.1 La idea
**Arrancás con los Digimon clásicos y vas consiguiendo otros a medida que jugás.** En cada run tu Digimon nace como bebé y **digievoluciona al subir de nivel**, hasta llegar a Mega si sobrevivís lo suficiente.

### 5.2 Digievolución por nivel (dentro de la run)
| Nivel | Etapa | Qué pasa |
|---|---|---|
| 1 | **In-Training** (ej. Koromon) | Arranque débil, solo el arma base. Dura poco, ~1 minuto |
| 5 | **Rookie** (Agumon) | Nuevo sprite, +stats y se habilitan más slots de armas |
| 15 | **Champion** (Greymon) | Ataque firma nuevo + onda que limpia la pantalla |
| 30 | **Ultimate** (MetalGreymon) | Cambio grande de poder. El sprite crece |
| 50 | **Mega** (WarGreymon) | Forma final, ataque firma definitivo. Habilita DNA Digivolution en co-op (post-MVP) |

- Cada evolución: animación corta (~1 s, **sin pausar el juego**, el jugador queda invulnerable), curación total, +stats y nuevo ataque firma que **se suma** a las armas, no las reemplaza.
- **Rutas alternativas según la build:** al llegar a Champion/Ultimate, si la mayoría de tus armas son de cierto tipo, cambia la línea. Ej.: armas "Virus" → Agumon evoluciona a **SkullGreymon** en vez de MetalGreymon. Descubrir rutas es parte de la colección.
- Si te pegan mucho siendo Mega no hay "des-evolución" en el MVP (la evolución siempre se siente como premio).

### 5.3 Roster inicial: los clásicos de Adventure
Desbloqueados desde la primera partida:

| In-Training | Rookie | Arma inicial | Champion | Ultimate | Mega | Ruta alternativa |
|---|---|---|---|---|---|---|
| Koromon | **Agumon** | Pepper Breath (proyectil al más cercano) | Greymon | MetalGreymon | WarGreymon | SkullGreymon |
| Tsunomon | **Gabumon** | Blue Blaster (cono frontal) | Garurumon | WereGarurumon | MetalGarurumon | — |
| Tokomon | **Patamon** | Boom Bubble (orbitales) | Angemon | MagnaAngemon | Seraphimon | — |

### 5.4 Digimon para conseguir
Se desbloquean jugando y quedan para siempre (progreso guardado). **Cómo se consiguen: Digi-Eggs**, bien al estilo Digimon.

1. Algunos enemigos y jefes **sueltan un Digi-Egg** de su especie (raro, con chance ajustable por Luck).
2. El huevo se lleva a **Primary Village** (menú del hub) y eclosiona después de N runs o pagando Bits.
3. Al eclosionar, ese Digimon queda jugable.

| Tanda | Digimon | Cómo se consigue |
|---|---|---|
| Resto de Adventure | Biyomon, Tentomon, Palmon, Gomamon | Huevos que sueltan enemigos de File Island |
| Gatomon | Salamon → Gatomon → Angewomon → Magnadramon | Huevo de Myotismon (jefe min 20, stage 2) |
| Enemigos reclutables | Leomon, Ogremon, Gazimon | Derrotarlos N veces (Digidex completo de esa especie) |
| Adventure 02 | Veemon, Wormmon, Hawkmon, Armadillomon | Stage 3 (post-MVP) |
| Tamers | Guilmon, Renamon, Terriermon | Stage 4 (post-MVP) |
| Secretos | Impmon (solo rutas dark), Omnimon (solo vía DNA) | Logros especiales |

**En co-op:** si cae un huevo, **le toca a cada jugador de la sala** (nadie se pelea por el loot y jugar acompañado se premia).

### 5.5 Roster completo: TODAS las temporadas (requisito)
**Requisito:** el juego tiene que tener a **todos los Digimon compañeros (partners) de todas las temporadas como jugables**, con sus líneas evolutivas, y a **los villanos principales de cada temporada como jefes**. El resto de las especies (hay más de 1.400 en total) va entrando como **enemigos comunes**, de a poco.

Cada temporada entra como un **"Season Pack"**: un stage temático + sus partners + sus jefes + su mecánica de evolución especial.

| # | Temporada | Partners jugables | Jefes / villanos | Mecánica especial |
|---|---|---|---|---|
| 1 | **Adventure** (1999) | Agumon, Gabumon, Biyomon, Tentomon, Palmon, Gomamon, Patamon, Gatomon | Devimon, Etemon, Myotismon, Dark Masters (MetalSeadramon, Puppetmon, Machinedramon, Piedmon), Apocalymon | Base: evolución por nivel |
| 2 | **Adventure 02** (2000) | Veemon, Hawkmon, Armadillomon, Wormmon | Kimeramon, BlackWarGreymon, Arukenimon y Mummymon, Daemon, MaloMyotismon | **Armor Digivolution** (Digi-Eggs de armadura como ítem) + DNA en co-op (Paildramon, Silphymon, Shakkoumon) |
| 3 | **Tamers** (2001) | Guilmon, Renamon, Terriermon, Lopmon, Guardromon, MarineAngemon, Impmon, Leomon | Los 12 Devas, Beelzemon (corrupto), D-Reaper | **Cartas** (Card Slash = power-ups temporales) + Biomerge |
| 4 | **Frontier** (2002) | Los 10 Legendary Warriors (Agunimon, Lobomon, Kazemon, Beetlemon, Kumamon, Loweemon, etc.) | Cherubimon, Duskmon, Royal Knights, Lucemon | **Spirit Evolution**: Human Spirit ↔ Beast Spirit (dos formas intercambiables) → Fusion |
| 5 | **Data Squad / Savers** (2006) | Agumon (Savers), Gaomon, Lalamon, Falcomon, Kudamon | Gizumon, Belphemon, King Drasil | **Burst Mode** (modo furia temporal a nivel Mega) |
| 6 | **Fusion / Xros Wars** (2010) | Shoutmon, Ballistamon, Dorulumon, Starmon, Cutemon, Greymon (Xros), MailBirdramon, Damemon | Bagramon, Tactimon, Lilithmon, Blastmon, DarkKnightmon, Quartzmon | **DigiXros**: fusionarte con Digimon aliados que juntás en la run |
| 7 | **Adventure tri.** + películas | Meicoomon, Ukkomon (02 The Beginning), Eosmon (Last Evolution) | Meicrackmon, Ordinemon, Eosmon, Diaboromon | Jefes de evento |
| 8 | **Adventure:** (2020) | Partners de Adventure con sus formas nuevas | Millenniummon, Negamon | Formas alternativas para los partners clásicos |
| 9 | **Ghost Game** (2021) | Gammamon, Angoramon, Jellymon | Digimon fantasma (Hologram Ghosts) | Stage nocturno con niebla y visión reducida |
| 10 | **Beatbreak** (2025) | *Verificar el roster en Wikimon* | *Verificar* | *Por definir* |
| — | Appmon (2016) | Spin-off con monstruos propios (Appmon), **no son Digimon** | — | Fuera del alcance salvo que se decida lo contrario |

**Tamaño estimado:** ~60 líneas jugables × ~5 formas = **~300 formas jugables**, más ~60 jefes y cientos de enemigos comunes.

**Qué implica para la producción:**
- **No se puede modelar todo a mano en Blender.** Para el volumen completo hay que partir de **sprites existentes** (las series *Digimon Story* y *Digimon World DS* cubren cientos de especies con sprites del mismo estilo). Blender queda para las formas clave y efectos.
- **Pipeline de datos:** script que arma los `.tres` de cada especie (nombre, etapa, atributo Vaccine/Data/Virus, línea evolutiva) desde una planilla armada con datos de Wikimon. Agregar un Digimon tiene que ser: sprite + una fila en la planilla.
- **Arma firma por línea**, no por forma: cada partner tiene 1 arma inicial + 4 ataques firma (uno por etapa). ~60 armas iniciales; muchas comparten patrón (proyectil, cono, órbita, aura) con distinto sprite y daño.
- **Release por temporadas:** MVP = parte de Adventure; después **un Season Pack por actualización** (~3–5 semanas cada uno). El orden sigue la tabla.

**Stats por personaje:** HP, Armor, Speed, Might (daño %), Area, Cooldown, Amount, Magnet, Luck, Recovery. Igual que VS para que el balance sea conocido. Cada etapa evolutiva multiplica las stats base de su línea.

---

## 6. Armas, pasivas, enemigos y jefes

### Armas (MVP: 10)
| Arma | Patrón | Evoluciona con | Evolución |
|---|---|---|---|
| Pepper Breath | Proyectil al más cercano | Pasiva "Fire Chip" | Nova Blast |
| Blue Blaster | Cono frontal | "Ice Chip" | Fox Fire |
| Boom Bubble | Orbitales | "Holy Ring" | Hand of Fate (rayo vertical) |
| Petit Thunder | Rayo a enemigo random | "Battery" | Electro Shocker |
| Poison Ivy | Látigo horizontal | "Leaf Chip" | Flower Cannon |
| Spiral Twister | Tornados que rebotan | "Feather" | Meteor Wing |
| Digi-Egg | Bomba de área (cae y explota) | "Crest of Courage" | Crest Burst |
| Horn Buster | Bumerán | "Data Shield" | Mega Horn |
| Garlic-like "Fire Wall" | Aura de daño alrededor | "Firewall Patch" | Infinity Wall |
| Virus Swarm | Minions que persiguen | "Corrupted Data" | Ultimate Virus |

### Pasivas (MVP: 10)
Chips de stats: Power Chip (Might), Speed Chip, Range Chip (Area), Cooldown Chip, Multi Chip (Amount), Magnet Chip, Armor Chip, HP Chip, Luck Chip, Recovery Chip. Las versiones elementales (Fire/Ice/Holy...) son las que habilitan evoluciones.

### Enemigos (MVP: File Island; Server Continent es el primer Season Pack)
- **Stage 1 — File Island:** Numemon, Kunemon, Goburimon, Tyrannomon, Ogremon, Gazimon, Bakemon (fantasma, atraviesa), Mojyamon.
- **Stage 2 — Server Continent:** Gekomon, Mekanorimon, Guardromon, Vilemon.
- Tipos de comportamiento: *chaser* (va directo), *swarmer* (rápido, poca vida), *tank* (lento, mucha vida), *ranged* (dispara), *charger* (embiste).

### Jefes
| Minuto | Stage 1 | Stage 2 |
|---|---|---|
| 10:00 | Leomon (mini-boss) | Etemon |
| 20:00 | Devimon | Myotismon |
| 30:00 | Apocalymon (invencible = "fin de la run") | Apocalymon |

---

## 7. Progresión a largo plazo (que el juego dure mucho)

**Objetivo:** que terminar la "historia" lleve **~30 horas** y completar el 100 % (todos los Digimon, todos los mapas) lleve **150–200 horas**, sin que se sienta repetitivo. Como referencia, Vampire Survivors al 100 % lleva ~60–80 h.

El juego se organiza en **6 capas de progreso** que avanzan en paralelo. En cada run avanzás varias a la vez.

```
Capa 1  Run (15–20 min)      nivel en la run → digievolución → sobrevivir
Capa 2  Vínculo del partner  cada Digimon sube de nivel de forma permanente → desbloquea etapas y rutas
Capa 3  Scan / Digidex       matar enemigos escanea su data → al 100 % podés criar ESA especie
Capa 4  Mapa del mundo       10 regiones (temporadas) × 4–6 mapas × 3 dificultades
Capa 5  Primary Village      hub: eclosionar huevos, tienda de mejoras, granja de Digimon
Capa 6  Endgame              modo infinito, raids co-op, desafíos semanales, logros
```

### 7.1 Capa 2: Vínculo del partner (lo que le da peso a cada Digimon)
Cada Digimon tiene un **nivel de vínculo permanente (1–20)** que sube con la XP de las runs que jugás con él.

| Vínculo | Desbloquea |
|---|---|
| 1 | Llegar hasta **Champion** dentro de la run |
| 5 | Llegar hasta **Ultimate** |
| 10 | Llegar hasta **Mega** |
| 12 | **Rutas alternativas** (SkullGreymon, BlackWarGreymon, etc.) |
| 15 | Ataque firma mejorado + skin alternativa (ej. versión Adventure: 2020) |
| 20 | **Forma especial**: Burst Mode / Mode Change (ej. WarGreymon X, Gallantmon Crimson Mode) |

Así un Digimon recién conseguido **no llega a Mega en su primera run**: hay que "criarlo", como en el V-Pet. Con ~300 formas, esta capa sola da cientos de horas.

### 7.2 Capa 3: Scan / Digidex (cómo se consiguen TODOS los Digimon)
Inspirado en *Digimon Story: Cyber Sleuth*:
- Cada enemigo derrotado suma **% de scan** de su especie (ej. +2 % por kill, +25 % por jefe).
- Al llegar al **100 %**, esa especie se puede **criar en Primary Village** y queda jugable.
- Así **cualquier especie** se puede conseguir, no solo los partners. La colección es enorme.

**Cómo se hace viable con más de 1.400 especies:**
| Tipo | Cantidad aprox. | Kit de ataques |
|---|---|---|
| **Partners** de las temporadas (5.5) | ~60 líneas | **Kit único**: arma propia + ataque firma por etapa |
| **Especies comunes** | cientos | **Kit por familia** (las 10 familias del juego de cartas: Nature Spirits, Deep Savers, Nightmare Soldiers, Wind Guardians, Metal Empire, Virus Busters, Dragon's Roar, Jungle Troopers, Dark Area, Unknown). Mismo patrón de ataque, distinto sprite, stats según el atributo Vaccine/Data/Virus |

Las especies comunes evolucionan siguiendo su línea real de Wikimon (cargada en la planilla de datos).

### 7.3 Capa 4: Mapa del mundo (muchos mapas)
El hub tiene un **mapa del Digital World** dividido en **10 regiones, una por temporada** (tabla 5.5). Cada región tiene **4–6 mapas**, y se completa derrotando al jefe final de la temporada.

| Región | Mapas (ejemplo) | Jefe final |
|---|---|---|
| File Island (Adventure) | Playa, Bosque Tropical, Fábrica, Montaña Infinita, Primary Village (defensa) | Devimon → Dark Masters → Apocalymon |
| Server Continent (Adventure) | Desierto, Coliseo de Etemon, Castillo de Myotismon, Spiral Mountain | Piedmon |
| Digital World 02 | Base del Emperador, Bosque de Torres de Control, Ciudad Destruida | MaloMyotismon |
| Shinjuku / Mundo Real (Tamers) | Shinjuku de noche, Hypnos, Zona de los Devas | D-Reaper |
| Digital World de Frontier | Forest Terminal, Ciudad Akiba, Rose Morning Star | Lucemon |
| DATS / Digital World (Savers) | Base DATS, Ciudad, Paraíso de los Royal Knights | King Drasil |
| Digital World de Xros Wars | Green Zone, Sword Zone, Dust Zone, Lake Zone | Bagramon / Quartzmon |
| Tokyo 2020 (Adventure:) | Tokio, Antena de comunicaciones, Mar de la Oscuridad | Millenniummon / Negamon |
| Ghost Game | Ciudad de noche con niebla, Escuela, Hospital | Jefe de temporada |
| Dark Area (secreta) | Mapas de los 7 Grandes Señores Demonio | Lucemon Satan Mode |

**Total: ~45 mapas.** Cada mapa tiene **3 dificultades** (con multiplicadores de recompensas y enemigos nuevos):
- **Normal**: sobrevivir 15 min.
- **Hard**: sobrevivir 20 min, enemigos ×2 de vida, nuevo jefe.
- **Ultimate**: 30 min, modificadores aleatorios (oscuridad, enemigos más rápidos, sin curación), mejores huevos.

Cada mapa además tiene **3 objetivos opcionales** ("derrotá a X sin recibir daño", "encontrá el Digi-Egg escondido", "terminá con un Digimon de la temporada"), que dan estrellas. Las estrellas desbloquean la región siguiente.

**Cuenta rápida:** 45 mapas × 3 dificultades × 3 objetivos = **405 estrellas**, además de los Digimon por criar.

### 7.3b Mapas con identidad (diseño)
Cada mapa tiene que reconocerse en una captura: **decorado icónico de la serie + una mecánica propia** que cambia cómo se juega. Todo es data (`StageData` + `PropData`), así que un mapa nuevo es armar su `.tres`.

| Mapa | Decorado de papel | Mecánica propia |
|---|---|---|
| **Playa de File Island** ✅ (prototipo) | Arena, palmeras, caracolas, **la fila de cabinas de teléfono**, mar con olas | El **mar es el borde** del mapa (te pueden acorralar contra el agua). Próximo: sonar una cabina → evento (cae un Digi-Egg o aparece un mini-jefe); cocos que caen al golpear palmeras |
| Bosque Tropical | Árboles gigantes, hongos, lianas | Árboles que **bloquean el paso** y hacen pasillos; Kuwagamon cruza la pantalla en picada |
| Fábrica | Engranajes, cintas, tuberías | **Cintas transportadoras** que empujan a todos; **Engranajes Negros** que potencian enemigos hasta que los rompés |
| Montaña Infinita | Nieve, rocas, lava | Hielo que **resbala** y ríos de lava que queman a todos (también a los enemigos) |
| Primary Village | Cunas, bloques de juguete, nubes | **Modo defensa**: proteger Digi-Eggs en cunas mientras llegan oleadas |
| Desierto / Coliseo de Etemon | Dunas, cactus, escenario con luces | **Tormentas de arena** que achican la visión; en el Coliseo la arena es cerrada |
| Castillo de Myotismon | Velas, vitrales, murciélagos | **Oscuridad**: solo ves lo que ilumina tu Digimon; Bakemon atraviesan paredes |
| Shinjuku (Tamers) | Edificios recortados de noche, carteles | **Cartas** que caen al piso como power-ups (Card Slash) |
| Ghost Game | Ciudad con niebla, faroles | **Niebla** que oculta enemigos hasta que están cerca |
| Dark Area | Papel negro y violeta, grietas | Sin luz y con enemigos que reaparecen |

### 7.4 Capa 5: Primary Village (hub)
- **Incubadora:** eclosionar Digi-Eggs (huevos que caen) y especies escaneadas al 100 %. Lleva un tiempo medido en **runs jugadas**, no en tiempo real (nada de esperas forzadas).
- **Tienda de Jijimon:** mejoras permanentes de stats con **Bits** (como el PowerUp de VS), ~15 stats con costo creciente.
- **Granja:** los Digimon que no estás usando suben vínculo pasivamente (+10 % de la XP de tus runs) para que cambiar de Digimon no castigue.
- **Digidex:** colección completa por temporada, familia y atributo, con % de completitud.
- **Sala de trofeos:** logros y estadísticas.

### 7.5 Capa 6: Endgame
| Modo | Qué es |
|---|---|
| **Dark Area infinita** | Sin límite de tiempo, la dificultad escala sin parar. Récord personal y entre amigos |
| **Raids de Royal Knights** (co-op) | Boss rush de los 13 Royal Knights, pensado para 4 jugadores. Recompensa: huevos de Royal Knights (Omnimon, Alphamon, Gallantmon, etc.) |
| **Siete Grandes Señores Demonio** | Jefes ultra difíciles en la Dark Area; dropean las especies demonio |
| **Desafío semanal** | Mismo mapa + misma semilla + modificadores para todos. Tabla de la semana entre amigos |
| **Logros** | ~300 logros, varios dan Digimon secretos |

### 7.6 Ritmo (para que no se termine rápido, pero tampoco aburra)
| Hito | Tiempo estimado |
|---|---|
| Primer Mega (Agumon → WarGreymon) | ~2 h |
| Terminar File Island | ~4 h |
| Terminar las 10 regiones en Normal ("créditos") | ~30 h |
| Todos los partners en Mega | ~80 h |
| 100 % (Digidex + 405 estrellas + Royal Knights) | 150–200 h |

**Reglas para que no se vuelva grind vacío:**
- Siempre avanzás **al menos 2 capas por run**, aunque mueras rápido (scan + vínculo).
- **En co-op se gana +25 % de todo** (scan, vínculo, Bits): premia jugar con amigos.
- Duplicados de huevos → vínculo extra para esa especie, nunca recompensas inútiles.
- Contenido nuevo por **Season Packs** (sección 10), así siempre hay algo nuevo.

### 7.7 Guardado
Con 150 h de progreso, **perder el save es inaceptable** (borrar el caché del navegador lo borra).
- Guardado local en IndexedDB (`user://`) + guardado automático después de cada run.
- **Cloud save con Supabase (plan gratis)**, sin pedir cuenta (ver 8.7):
  - Al abrir el juego por primera vez se hace un **login anónimo** (Supabase Anonymous Sign-In): el jugador ni se entera y ya tiene un ID propio.
  - El save se sube comprimido después de cada run.
  - Para pasar el progreso a otra PC o navegador: **código de transferencia** (ej. `DIJI-8F2K-QX7P`) u opción de **vincular Google/email** (opcional, convierte la cuenta anónima en permanente).
- Exportar/importar save como archivo, como respaldo.
- **Esto entra en el MVP**, no después.

---

## 8. Arquitectura técnica

### 8.1 Stack
| Pieza | Decisión | Por qué |
|---|---|---|
| Motor | **Godot 4.4+ (o la última estable)** | Export web maduro, liviano, gratis |
| Renderer | **Compatibility (WebGL 2)** | Es el único que funciona en web; Forward+/Mobile no |
| Lenguaje | **GDScript** | C# **no se puede exportar a web** en Godot 4 |
| Threads | Export **single-threaded** (default desde 4.3) | Evita requerir headers COOP/COEP (SharedArrayBuffer), así funciona en itch.io y cualquier hosting estático |
| 3D / arte | **Blender 4.x** | Modelado + render a sprite sheets |
| Hosting | itch.io (MVP) → Cloudflare Pages / Vercel | Estático, gratis, CDN |
| Red | WebRTC P2P + señalización por Supabase Realtime (ver 8.6) | Online sin servidor de juego pago |
| Backend | **Supabase (plan gratis)**: auth anónima, cloud save, salas, tablas semanales (ver 8.7) | Gratis, todo en un solo servicio |

### 8.2 2D vs 3D: decisión clave
Para web con 500+ enemigos, **3D en tiempo real es caro** en WebGL. Recomendación:

**Juego 2D con sprites pre-renderizados desde Blender** (técnica de Dead Cells / Donkey Kong Country):
1. Modelás (o importás) el Digimon en Blender, low-poly.
2. Lo animás (idle, walk, attack, hit, death).
3. Cámara ortográfica fija en ángulo top-down / 3/4, render en 8 direcciones (o 2 con flip horizontal, más barato).
4. Shader toon + outline (Freestyle o inverted hull) → look pixel/cel.
5. Script de Blender (Python) que renderiza todas las animaciones a PNG y arma el sprite sheet.
6. Godot importa el sheet en `SpriteFrames` / `AnimatedSprite2D`.

Ventajas: el look 3D del arte con el costo de rendering de 2D; Blender queda en el pipeline sin pagar el precio en el navegador.

**Alternativa:** si querés 3D real, usar modelos de < 1.500 tris, `MultiMeshInstance3D` para enemigos y animación por vertex shader. Más riesgoso para mobile.

### 8.2b Dirección de arte: papel 2.5D (estilo Paper Mario) — decisión
- **Mundo 3D, personajes 2D de papel.** Los Digimon son los sprites pixel art del pipeline de Blender, dibujados como **recortes de papel** sobre quads que miran a la cámara: borde blanco de papel, sombra en el piso y **giro de "hoja"** al cambiar de dirección.
- **Piso y decorado de papel**: piso con manchas recortadas y fibra de papel; decorados (palmeras, rocas, cabinas…) como recortes con borde blanco y una mitad en sombra. Todo procedural en shaders (sin texturas extra).
- **Cámara en perspectiva** inclinada (~45°), render a 640×360 escalado: pixel art + papel.
- **La simulación sigue siendo 2D** (en píxeles); `PaperView` solo la dibuja en 3D. Esto mantiene el netcode simple (8.6) y permite cambiar el look sin tocar la lógica.
- **Rendimiento web**: un `MultiMesh` por especie/animación con datos por instancia (frame, giro, destello); cientos de enemigos en una sola llamada de dibujo por especie.

### 8.3 Performance (lo que hace o rompe a un survivors-like)
- **No usar un nodo `CharacterBody2D` por enemigo.** Con cientos de enemigos se cae el FPS. En su lugar:
  - Enemigos como datos en arrays (posición, velocidad, HP) actualizados en un solo `_physics_process`.
  - Render con `MultiMeshInstance2D` o `RenderingServer` directo.
  - Colisiones con **spatial hash grid** propio (celdas de 64 px) en vez de física de Godot.
- **Object pooling** para proyectiles, gemas de XP, números de daño.
- Fusionar gemas de XP cercanas cuando hay más de N en pantalla (VS lo hace).
- Separación entre enemigos simple (boids light) calculada cada 2–3 frames.
- Presupuesto: 500 enemigos + 300 proyectiles + 400 gemas a 60 FPS en desktop medio.

### 8.4 Estructura data-driven
Todo el contenido como **Resources (`.tres`)** de Godot, no hardcodeado:

```
dijimones/
├─ game/                      # proyecto Godot
│  ├─ core/                   # loop, spawner, spatial hash, pools
│  ├─ data/
│  │  ├─ characters/*.tres    # CharacterData: stats, línea evolutiva, sprites
│  │  ├─ weapons/*.tres       # WeaponData: patrón, niveles, evolución
│  │  ├─ passives/*.tres
│  │  ├─ enemies/*.tres       # EnemyData: comportamiento, stats, sprite
│  │  └─ stages/*.tres        # tabla de oleadas por minuto, jefes
│  ├─ ui/
│  └─ assets/sprites|sfx|music
├─ blender/                   # .blend fuente + script render_spritesheet.py
└─ docs/PRD.md
```
Así cambiar Digimon → monstruos originales (opción C del punto 2) es reemplazar `.tres` y sprites.

### 8.5 Web: detalles a cuidar
- Tamaño del `.pck` + `.wasm`: objetivo < 15 MB comprimido (Brotli/gzip en el hosting).
- Audio: los navegadores bloquean el audio hasta el primer input → pantalla "Click para empezar".
- Pantalla completa y escalado: viewport 640×360 escalado entero (pixel perfect) o `canvas_items` stretch.
- Mobile: joystick virtual, UI más grande, menos partículas (preset "low").
- Guardado en IndexedDB vía `user://`: avisar que borrar datos del navegador borra el progreso.

---

### 8.6 Multijugador online (co-op)

### Diseño de juego
| Aspecto | Decisión |
|---|---|
| Modo | **Co-op online de 1 a 4 jugadores**. Single player = sala de 1, mismo código |
| Entrar a una partida | **Solo salas privadas**: código de sala (ej. `AGU-4821`) o link para compartir (`dijimones.io/#AGU-4821`). Sin matchmaking público |
| Comunicación | **Solo emotes y pings** (rueda de 8 emotes + marcar un lugar del mapa). Sin chat de texto, así no hace falta moderar |
| Cuenta | No hace falta: nombre + Digimon elegido. El progreso meta sigue siendo local |
| Personajes | Cada jugador elige su Digimon. Se puede repetir |
| XP | **Compartida**: cualquier Data que se junte suma para todos, así nadie queda atrás |
| Level up | **No se pausa** el juego (no se puede pausar a 4 personas). El menú de cartas aparece en una esquina, el jugador queda **invulnerable hasta 5 s** mientras elige y sus armas siguen disparando |
| Cofres | Para el que los abre |
| Muerte | El jugador queda caído como **Digi-Egg**; un compañero lo revive parándose al lado 3 s. Si caen todos, fin de la run |
| Escalado | HP de enemigos y cantidad de spawns × (1 + 0,6 por jugador extra); jefes × (1 + 0,8) |
| Pausa con Esc | Solo en single player. En co-op, Esc abre el menú sin frenar el juego |
| Desconexión | El Digimon del jugador desaparece; si vuelve en < 60 s recupera su build |

**Feature estrella (post-MVP): DNA Digivolution (Jogress).** Si dos jugadores en etapa Mega se quedan juntos 3 s, se fusionan durante 20 s en una forma combinada (WarGreymon + MetalGarurumon → **Omnimon**). Un jugador maneja y el otro apunta un ataque especial. Es el momento para compartir en redes y es exclusivo del co-op.

### Arquitectura de red
| Pieza | Decisión | Por qué |
|---|---|---|
| Modelo | **Host autoritativo**: el navegador del creador de la sala simula todo (enemigos, daño, drops) y los demás mandan solo su input/posición | No hace falta un servidor de juego pago, clave para un juego gratis |
| Transporte | **WebRTC** (`WebRTCMultiplayerPeer` de Godot), canales *unreliable* para snapshots y *reliable* para eventos | Funciona en navegador y es P2P. **ENet no funciona en web** |
| Señalización / salas | **Supabase Realtime Broadcast**: un canal por código de sala (ver 8.7) | Solo intercambia ofertas WebRTC y códigos de sala, gratis y en el mismo servicio que el save |
| NAT difícil | Servidor **TURN** de respaldo (Cloudflare Realtime TURN o metered.ca, con capa gratis) | Entre el 10 y el 20 % de las conexiones no logran P2P directo |
| Sincronización | Se usan RPC con `PackedByteArray` propios, no `MultiplayerSynchronizer` por enemigo | Los nodos de sync de Godot no escalan a 500 enemigos |

**Formato de snapshot (host → clientes, 15 Hz):**
- Enemigos: id (u16) + posición cuantizada (2 × i16) + estado (u8) = 7 bytes. 500 enemigos ≈ 3,5 KB, con delta (solo los que cambiaron) + compresión ≈ 1–2 KB.
- Jugadores: posición, HP, animación.
- Eventos *reliable*: spawn de jefe, muerte de enemigo, drop, level up, digievolución.
- Upload del host con 3 clientes ≈ 60–100 KB/s: aguanta cualquier conexión de hogar.

**Cliente:**
- Interpola los enemigos 100 ms en el pasado, así se ven suaves aunque lleguen 15 snapshots por segundo.
- Mueve a su propio Digimon al instante (predicción) y corrige si el host no está de acuerdo.
- Proyectiles y efectos visuales se simulan localmente a partir de eventos ("el jugador 2 disparó Pepper Breath con semilla X"), no se sincronizan uno por uno.
- Las gemas de XP se sincronizan como eventos de drop/recolección, no por frame.

**Implicancias en el código desde el día 1:**
- La **simulación separada del render**: `GameState` puro (arrays de datos) que corre solo en el host y un `View` que dibuja lo que llega.
- RNG con **semilla compartida** por sala para spawns y efectos visuales.
- Single player = host sin clientes. **Un solo camino de código**, nada de "modo online" aparte.

**Riesgos propios del online:**
- Si el host se va, termina la partida para todos (en el MVP no hay migración de host). Mitigación: avisar en el lobby quién es el host; *host migration* post-MVP.
- Trampas: el host puede hacer trampa. Al ser co-op y gratis, se acepta. Si algún día hay leaderboards, se validan aparte.
- Latencia: con 150 ms o más, los golpes se sienten tarde. Como es co-op, se tolera; en el lobby se muestra el ping.

### 8.7 Backend: Supabase (plan gratis)
Un solo servicio gratis para **guardado, identidad, salas online y tablas semanales**.

| Uso | Feature de Supabase | Detalle |
|---|---|---|
| Identidad sin cuenta | **Anonymous Sign-In** | ID de usuario sin email; después se puede vincular Google/email |
| Cloud save | **Postgres** + Row Level Security | 1 fila por jugador, cada uno solo puede leer y escribir la suya |
| Señalización WebRTC / salas | **Realtime Broadcast** (canal = código de sala) | Reemplaza al servidor de Cloudflare: los jugadores se intercambian las ofertas WebRTC por el canal y después se desconectan |
| Desafío semanal | Postgres | Tabla de puntajes por semana/semilla |
| Códigos de transferencia | Postgres + Edge Function | Genera el código y, al canjearlo, asigna el save al nuevo ID |

**Esquema mínimo:**
```sql
create table saves (
  user_id    uuid primary key references auth.users on delete cascade,
  data       text not null,        -- JSON comprimido (gzip + base64)
  version    int  not null default 1,  -- se incrementa en cada guardado
  updated_at timestamptz not null default now()
);
alter table saves enable row level security;
create policy "own save" on saves for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table weekly_scores (
  week      date not null,
  user_id   uuid references auth.users on delete cascade,
  name      text not null,
  score     int  not null,
  primary key (week, user_id)
);
```

**Conflictos:** si el jugador tiene el juego abierto en dos navegadores, el save lleva `version`; se sube solo si la versión del servidor es la esperada. Si no, gana la que tenga más progreso (más tiempo jugado), y el save local se mantiene siempre como respaldo.

**Tamaño del save:** vínculo de ~300 formas + scan de ~1.400 especies + estrellas + desbloqueos ≈ 30–60 KB en JSON, **~5–10 KB comprimido**. 500 MB de base dan para **más de 50.000 jugadores**.

**Límites del plan gratis** (verificar los actuales en supabase.com/pricing):
| Límite | Valor aprox. | ¿Alcanza? |
|---|---|---|
| Base de datos | 500 MB | Sí, más de 50k saves |
| Usuarios activos por mes (auth) | 50.000 | Sí |
| Conexiones Realtime simultáneas | 200 | Sí: solo se usan durante el lobby, unos segundos por partida |
| Mensajes Realtime | ~2 millones por mes | Sí: unos 20–50 mensajes por sala |
| **Pausa por inactividad** | El proyecto se pausa tras **7 días sin actividad** | Con jugadores reales no pasa. En desarrollo: un cron gratis (GitHub Actions) que haga un ping diario |

**Integración con Godot web:** llamadas a la API REST de Supabase con `HTTPRequest` y Realtime por `WebSocketPeer`, o el addon comunitario de Supabase para Godot 4. La clave `anon` es pública por diseño: la seguridad la da RLS.

**Trampas:** el save lo genera el cliente, así que alguien podría editarlo. Como el juego es co-op y gratis, se acepta. La única validación del lado del servidor es un tope razonable en `weekly_scores`.

**Si algún día queda chico:** el plan Pro cuesta ~USD 25 por mes. Alternativa gratis: Cloudflare D1 + Workers, que no se pausa, pero hay que armar la autenticación a mano.

## 9. Dónde conseguir assets

### 9.1 Assets de Digimon (⚠️ con copyright, solo para prototipo / fan game, ver punto 2)
| Fuente | Qué hay | Uso |
|---|---|---|
| **The Spriters Resource** (spriters-resource.com) | Sprites rippeados de Digimon World (PS1/DS), Digimon Story DS, Digimon Battle Spirit (GBA), Digimon Adventure (WonderSwan), etc. Ideal para 2D | Placeholder / fan game |
| **The Models Resource** (models-resource.com) | Modelos 3D rippeados (Digimon World, Cyber Sleuth, Rumble Arena) → importables en Blender para el pipeline de pre-render | Placeholder / fan game |
| **The Sounds Resource** (sounds-resource.com) | SFX y voces rippeadas | Placeholder |
| **Wikimon** (wikimon.net) | Base de datos: líneas evolutivas, atributos (Vaccine/Data/Virus), nombres de ataques | Diseño de datos (los datos/hechos en sí no son el problema, el arte sí) |
| **Digimon Wiki (Fandom)** | Referencia de ataques y apariciones | Diseño |
| **DeviantArt / Pixiv** | Fan art y pixel art de fans | Solo con permiso explícito del artista |

### 9.2 Assets libres / con licencia (para el juego publicable)
| Fuente | Qué hay | Licencia |
|---|---|---|
| **Quaternius** (quaternius.com) | Packs low-poly de monstruos animados (Ultimate Monsters, etc.) → perfectos para el pre-render en Blender | CC0 |
| **Kenney** (kenney.nl) | UI, partículas, sprites, SFX | CC0 |
| **KayKit** (kaylousberg.itch.io) | Personajes y props low-poly | CC0 |
| **Poly Pizza** (poly.pizza) | Modelos low-poly | CC0 / CC-BY |
| **itch.io → Game Assets** | Packs pixel art de monstruos y survivors-likes (muchos a USD 5–20) | Según cada pack |
| **OpenGameArt** (opengameart.org) | Sprites, música, SFX | CC0 / CC-BY / GPL (revisar cada uno) |
| **Mixamo** | Animaciones para modelos humanoides | Gratis con cuenta Adobe |
| **Freesound** (freesound.org) | SFX | CC0 / CC-BY |
| **jsfxr / ChipTone** | Generadores de SFX retro | Lo que generás es tuyo |
| **Juhani Junkala / OpenGameArt chiptune packs** | Música chiptune | CC0 |

**Estrategia de assets sugerida:**
1. **Prototipo (semanas 1–4):** sprites de The Spriters Resource (Digimon World DS / Digimon Story tienen sprites top-down muy útiles).
2. **Vertical slice:** 3 personajes modelados/retocados en Blender y pre-renderizados con el pipeline propio, para validar el look.
3. **Lanzamiento (gratis):** sprites retocados/pre-renderizados propios de los Digimon. Plan B ante DMCA: diseños originales (comisionar ~USD 50–150 por monstruo en pixel art, o modelar sobre bases CC0 de Quaternius).

---

### 9.3 Cantidad de Digimon y fuente de assets (decisión)

**Cuántos Digimon hay:**
| Grupo | Juego completo | MVP (File Island) |
|---|---|---|
| Partners jugables con kit único | ~60 líneas ≈ **300 formas** | 3 iniciales + 4 desbloqueables = 7 líneas ≈ 35 formas |
| Jefes | ~60 | ~6 (Leomon, Ogremon, Devimon y su forma final, Apocalymon) |
| Especies criables por scan (kit por familia) | **~400–500**, limitado por los modelos que existan | ~25 (las de File Island) |
| Enemigos por mapa | 8–15 especies | 8–15 |
| **Total de especies distintas** | **~500–600** | **~40** |

No van las más de 1.400 especies que existen: muchas no tienen ningún modelo ni sprite usable, y hacerlas a mano no escala. Regla: **todos los partners y villanos de todas las temporadas sí; el resto, hasta donde alcancen los assets.**

**Fuente de assets elegida: modelos 3D de los juegos *Digimon Story* → Blender → sprites.**
1. **Fuente principal:** modelos 3D de *Digimon Story: Cyber Sleuth / Hacker's Memory* (~340 especies) y *Digimon Story: Time Stranger* (2025, ~450 especies), de The Models Resource u otras comunidades de ripeo. **Verificar qué está disponible** antes de empezar.
2. **Pipeline:** se importan a Blender, se les pone **un mismo shader toon + contorno**, y un script los renderiza a sprite sheets (8 direcciones o 2 con espejo) con la misma cámara y escala. Así **todo el roster se ve como un solo juego**, aunque venga de juegos distintos.
3. **Animaciones:** se reutilizan las animaciones que traen los modelos (idle, caminar, atacar, recibir daño); se renderizan solo 4–6 por especie.
4. **Huecos** (partners de temporadas que esos juegos no cubren, como algunos de Xros Wars, Ghost Game o los Legendary Warriors de Frontier): modelos de *Digimon Masters Online* o *Digimon New Century* si existen; si no, se modelan en Blender en low-poly con el mismo shader.
5. **Fallback 2D:** sprites de *Digimon World DS* / *Digimon Story DS* (The Spriters Resource) para prototipar antes de que el pipeline 3D → sprite esté listo.

**Estética unificada (decisión):** todos los Digimon tienen que verse del mismo juego, vengan de donde vengan. Los modelos de los juegos oficiales **no se usan tal cual**: se usan como **referencia/base** y todos pasan por el mismo proceso de "remodelado" en Blender:
1. **Base:** modelo de los juegos (si existe) o, para los que no tienen, un modelo nuevo a partir del arte oficial de Wikimon (a mano o con image-to-3D como Meshy / Tripo / Hunyuan3D como punto de partida).
2. **Low-poly uniforme:** decimado/retopología a un presupuesto fijo (~1.500–3.000 tris según tamaño), mismas proporciones de escala por etapa (In-Training chico → Mega grande).
3. **Material único:** se descartan las texturas originales; se proyecta una **paleta plana de pocos colores** (sacada del modelo/arte original) + shader toon de 2–3 tonos + contorno del mismo grosor.
4. **Rig y animaciones estándar** por tipo de cuerpo (bípedo, cuadrúpedo, volador, serpiente, blob): idle, caminar, atacar, golpe, muerte. Mismas poses y timing para todos.
5. **Render** a sprite sheet con la misma cámara, luz y escala (script de Blender).

Así se ven todos iguales y además se toma distancia de los assets rippeados (son base, no producto final).

**Primera tarea de assets:** armar una planilla con las ~600 especies objetivo y, para cada una: si hay modelo, de qué juego, sus animaciones y su línea evolutiva (de Wikimon). Esa planilla define el roster final.

## 10. Alcance MVP y roadmap

### MVP (vertical slice jugable)
- Mapa del mundo con la región 1 jugable (el resto bloqueado, se muestra como "próximamente").
- 3 clásicos iniciales (Agumon, Gabumon, Patamon) con línea In-Training → Mega.
- 4 desbloqueables vía Digi-Eggs (Biyomon, Tentomon, Palmon, Gomamon) + Primary Village.
- 10 armas (+ evoluciones), 10 pasivas.
- 8 enemigos + 2 jefes + Apocalymon.
- Progresión: vínculo de partner, scan/Digidex, Primary Village, tienda de Jijimon y cloud save con código.
- Región File Island completa (5 mapas × 3 dificultades) con estrellas.
- **Online co-op 1–4 jugadores** con código de sala y link, revive y XP compartida.
- Export web en itch.io, desktop.

### Roadmap
| Fase | Duración estimada | Entregable |
|---|---|---|
| 0. Setup | 1 semana | Proyecto Godot, export web funcionando en itch.io (draft), pipeline Blender → sprite sheet probado con 1 modelo |
| 1. Core loop | 2–3 semanas | Movimiento, 1 arma, spawner con spatial hash, XP, level up con 3 cartas, 300+ enemigos a 60 FPS. **Simulación separada del render** |
| 1b. Netcode | 3–4 semanas | Proyecto Supabase + auth anónima, señalización por Realtime, salas con código, WebRTC, snapshots de enemigos, interpolación, 4 jugadores probados entre redes distintas |
| 2. Contenido MVP | 3–4 semanas | 10 armas, 10 pasivas, 8 enemigos, jefes, digievolución en partida |
| 3. Meta + UI | 3–4 semanas | Mapa del mundo, Primary Village, vínculo, scan, Digidex, tienda, cloud save, audio |
| 4. Polish + playtest | 2 semanas | Juice (screen shake, hit-stop, partículas), balance, mobile táctil |
| 5. Season Packs | ~3–5 semanas c/u | Una temporada por actualización (tabla 5.5): stage + partners + jefes + mecánica especial. ~10 packs para tener **todos** |
| 6. Post-MVP | continuo | Rutas dark, modo hiper, **DNA Digivolution**, host migration, eventos |

**Total MVP: ~16–20 semanas** (el online suma ~3–4 y la progresión larga ~2) a tiempo parcial con una persona (o la mitad con IA asistiendo el código).

---

## 11. Riesgos y preguntas abiertas

### Riesgos
| Riesgo | Impacto | Mitigación |
|---|---|---|
| DMCA de Bandai Namco | Alto: te bajan el juego | No monetizar, no usar logos oficiales, arquitectura data-driven para migrar a monstruos originales |
| Performance en WebGL / mobile | Alto: un survivors-like lento no se juega | Sin nodos por enemigo, MultiMesh, spatial hash, profiling desde la fase 1 |
| Volumen de contenido (todas las temporadas ≈ 300 formas jugables) | **Alto** | Releases por Season Pack, pipeline de datos desde planilla, sprites existentes en vez de modelar todo, armas que comparten patrones |
| Netcode con 500 enemigos | Alto | Host autoritativo + snapshots compactos + interpolación; prueba de carga con 4 jugadores en la fase 1b, antes de hacer contenido |
| Conexiones que no logran P2P | Medio | TURN de respaldo; mostrar error claro y sugerir otra red |
| Pipeline Blender lento | Medio | Automatizar render con script Python desde el día 1; 2 direcciones + flip en vez de 8 |
| Balance | Medio | Valores en `.tres`, modo debug con spawn de armas/enemigos y velocidad x4 |

### Preguntas abiertas
1. ~~¿Fan game o juego original?~~ **Resuelto:** fan game gratis (A → B), con plan de salida a la C si hay DMCA.
2. ¿Pixel art puro o pre-render 3D desde Blender? (Recomendado: pre-render, es lo que justifica Blender.)
3. ¿Mobile en el MVP o solo desktop?
4. ~~¿Multijugador?~~ **Resuelto:** online co-op 1–4 jugadores desde el MVP (ver 8.6).
6. ~~¿Matchmaking público?~~ **Resuelto:** alcanza con salas privadas por código/link. Matchmaking público fuera de alcance.
7. ~~¿Chat?~~ **Resuelto:** solo emotes y pings rápidos ("¡acá!", "ayuda", "revivime"). Sin chat libre.
8. ¿Appmon cuenta como "todas las temporadas"? (Recomendado: no, son otra franquicia.)
9. ¿Qué orden de Season Packs después de Adventure? (Propuesta: el de la tabla 5.5.)
5. ~~¿Monetización?~~ **Resuelto:** gratis, sin monetización (ver punto 2).
