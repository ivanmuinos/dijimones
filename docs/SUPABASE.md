# Supabase para Dijimones

Lo usamos para: **jugar online** (señalización de salas), **login de invitado**, **rankings**, **clanes** y **guardado en la nube**.
El juego en sí entre jugadores va **directo entre navegadores (WebRTC)**; Supabase solo los presenta.

## 1. Crear el proyecto (plan gratis)
1. https://supabase.com → New project.
2. Nombre: `dijimones`. Región: **South America (São Paulo)** (la más cercana a Argentina).
3. Guardar la contraseña de la base en un lugar seguro (no hace falta pasármela).

## 2. Configurar
1. **Authentication → Sign In / Providers → "Allow anonymous sign-ins": activar.** (Así se juega como invitado, sin cuenta.)
2. **SQL Editor → New query →** pegar todo `supabase/schema.sql` → **Run**. Crea las tablas de perfiles, runs, clanes y saves con su seguridad.
3. **Realtime:** no hay que tocar nada (usamos "Broadcast", viene activado).
   - Si en Realtime → Settings está activado **"Allow public access" = off / solo canales privados**, dejarlo permitiendo canales públicos.

## 3. Qué me tenés que pasar
| Dato | Dónde está | ¿Es secreto? |
|---|---|---|
| **Project URL** (`https://xxxx.supabase.co`) | Project Settings → Data API (o el botón "Connect") | No |
| **Publishable key** (o "anon public" key, empieza con `sb_publishable_` o `eyJ...`) | Project Settings → API Keys | **No**: está pensada para ir en el juego; la seguridad la dan las políticas del SQL |

**No me pases** la `service_role` / `secret` key ni la contraseña de la base: esas sí son secretas y el juego no las necesita.

## 4. Opcional (más adelante): TURN
Entre un 10 y 20 % de las conexiones no logran conectarse directo (redes de facultad/oficina, algunos 4G).
Para esos casos hace falta un servidor TURN. Opciones con capa gratis: **Cloudflare Realtime TURN** (ya tenemos cuenta)
o **metered.ca**. Lo configuramos cuando el online esté andando.

## Límites del plan gratis que nos importan
- 50.000 usuarios activos por mes, 500 MB de base: sobra.
- Realtime: 200 conexiones simultáneas; solo se usan unos segundos al armar la sala.
- **El proyecto se pausa tras 7 días sin uso**: se reactiva desde el panel (o con jugadores no pasa).
