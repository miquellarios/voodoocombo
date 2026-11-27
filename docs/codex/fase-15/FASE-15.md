# Fase 15 — Jugar desde casa con un enlace: servidor en internet, versión web e invitaciones

> **Para Codex.** Antes de empezar:
> 1. La **fase 14** tiene que estar terminada. Sobre todo 14a (el cuelgue) y 14b (cola de entradas y snapshot en un paquete).
> 2. **Copia `docs/codex/fase-15/AGENTS.md` a la raíz como `AGENTS.md`.** Cambia §2 (versión web) y §5 (red).
> 3. Referencias en `docs/media/`:
>    - `jugar_online_referencia.png`: pantalla JUGAR;
>    - `invitar_referencia.png`: lobby con INVITAR y lo que vive el amigo.
> 4. El despliegue ya está hecho por Claude en `deploy/`, con la guía para humanos en `docs/SERVIDOR-ONLINE.md`. **No lo cambies** salvo que algo de esta fase lo pida. Si lo cambias, apúntalo en la bitácora.
> 5. **Si en la fase 14 hiciste la versión antigua de 14c** (código de invitación con la IP dentro, UPnP o detección de VPN), **no lo borres**: muévelo dentro de SIN INTERNET → "Alojar en mi PC". La forma principal de jugar desde casa pasa a ser la de esta fase.
>
> ⚠️ **El servidor se actualiza solo desde `main`.** Cada 10 minutos mira GitHub y, si hay commits nuevos y nadie jugando, regenera la web y el `.exe` y se reinicia (`deploy/actualizar.sh --auto`). Así que:
> - **no hagas `push` a `main` de nada que no arranque**;
> - ejecuta los tests antes de cada `push`;
> - si un bloque se queda a medias, haz el `push` cuando funcione.

## El objetivo del equipo

El profesor da mucha importancia a que **dos personas puedan jugar juntas desde su casa de forma sencilla**. Tiene que ser así, sin margen de error:

1. Miquel abre `https://voodoocombo.duckdns.org` en el navegador, o el `.exe`.
2. Pulsa **CREAR SALA** y luego **INVITAR**: se copia un enlace, que manda por WhatsApp.
3. Su amigo toca el enlace. Se abre el juego en el navegador, le pide el nombre si es la primera vez y **aparece directamente en la sala**.
4. Los dos pulsan ¡LISTO! y juegan.

**Ni IPs, ni puertos, ni cortafuegos, ni VPN, ni instalar nada.**

## Cómo está montado (ya funciona, lo probó Claude)

```
Navegador / .exe  --wss://DOMINIO/ws-->  Caddy (HTTPS, 443)  --ws://127.0.0.1:7780-->  servidor Godot (--server --ws)
Navegador         --https://DOMINIO/-->  Caddy  -->  /opt/voodoocombo/web (exportación "Web")
```

- **Máquina:** Oracle Cloud Always Free en Madrid, con Ubuntu 24.04.
- **`deploy/instalar_servidor.sh` instala:**
  - Godot 4.7.2 sin pantalla;
  - las plantillas de exportación;
  - Caddy, que pone el certificado HTTPS solo;
  - el servicio `voodoocombo.service`, que se reinicia solo;
  - DuckDNS.
- **`deploy/actualizar.sh`** (lo lanza solo un temporizador cada 10 minutos):
  - baja `main` e importa el proyecto;
  - exporta el preset **"Web"** a la carpeta de la web y el preset **"Windows"** a `https://DOMINIO/descargar/VoodooCombo-Windows.zip`;
  - reinicia el servidor.
- **Comprobado por Claude con Godot 4.7.2:**
  - `WebSocketMultiplayerPeer` funciona a través de Caddy en la ruta `/ws`: el servidor acepta la conexión aunque la URL lleve ruta;
  - el proyecto actual ya se exporta a web (unos 54 MB, que con gzip bajan mucho) y arranca en Chrome hasta el menú.

---

## Cómo trabajar esta fase

- Son 8 bloques (**15a-15h**), con un commit por bloque (`Fase 15a: <resumen>`).
- Para probar en local sin Oracle, usa el ejemplo de Caddy en **15h**.
- Todos los textos van por I18n y todos los números en `GameConfig`.

## 15a · Transporte WebSocket (servidor y cliente)

En el **servidor** (`net/server_main.gd`), nuevos argumentos:
- `--ws`: usa `WebSocketMultiplayerPeer.create_server(port, bind)` en vez de ENet.
- `--bind <dirección>`: por defecto `"*"`; en Oracle se usa `127.0.0.1`.
- `--port`: ya existe. Con `--ws`, por defecto **7780**.
- Sin `--ws`, todo sigue con ENet en UDP 7777, como ahora: lo usan "Alojar en mi PC" y el servidor de clase.
- Todo pasa por `Net.start_server(...)`. El resto del código no cambia, porque usa la API `multiplayer`.

En el **cliente**, `Net.join_server(destino)`:
- si `destino` empieza por `ws://` o `wss://`, usa `WebSocketMultiplayerPeer.create_client(destino)`;
- si no, usa ENet (IP en la red local).

**Notas:**
- WebSocket va siempre por TCP fiable y en orden: `unreliable` y los canales no tienen efecto. Así que **mantén los snapshots pequeños** (14b, menos de 1000 bytes) y a 20 Hz. No cambies nada más.
- `HttpEndpoint` sigue en 8080. En Oracle no se abre a internet: Caddy lo publica como `/estado` y `/resultados`.

**Prueba:** servidor con `--ws --bind 127.0.0.1` + 2 clientes `ws://127.0.0.1:7780` → crear sala, unirse, jugar una partida entera.

## 15b · Dónde está el servidor: un solo archivo

- **`assets/servidor.json`:**
  ```json
  {"ws_url": "wss://voodoocombo.duckdns.org/ws", "web_url": "https://voodoocombo.duckdns.org"}
  ```
  - Lo leen el juego y el `.exe`. Si cambia el dominio, se toca **solo ese archivo**.
  - Tiene que incluirse en la exportación: el filtro ya incluye `assets/**/*.json`.
- **En la web**, la dirección del servidor se calcula de la página:
  - `wss://` + `location.host` + `/ws` si la página es `https:`, y `ws://` si es `http:` (pruebas en local);
  - con `JavaScriptBridge.eval("location.protocol")` y `JavaScriptBridge.eval("location.host")`;
  - así funciona aunque cambie el dominio.
- **AJUSTES → ONLINE → Avanzado:** campo para otra URL (para pruebas) y **RESTABLECER**.
- **Estado del servidor**, arriba en la pantalla JUGAR:
  - el juego intenta conectar y mide el ping;
  - ● verde "Servidor conectado · 32 ms";
  - ● rojo "Servidor en mantenimiento. Puedes jugar contra bots o sin internet".
  - Nunca se queda colgado: timeout de 5 s.

## 15c · Pantalla JUGAR nueva (online primero)

Tiene que quedar como `docs/media/jugar_online_referencia.png`. Sustituye a la de la fase 14.

**JUGAR CON AMIGOS** (tarjeta grande, a la izquierda) → **CREAR SALA**:
1. conecta al servidor;
2. pasa por ELIGE MODO;
3. crea la sala;
4. entra al lobby.

**PARTIDA RÁPIDA** → **BUSCAR PARTIDA** (bloque 15e).

**¿TE HAN PASADO UN ENLACE O CÓDIGO?**
- Un campo y **ENTRAR**.
- **Acepta:**
  - el enlace entero (`https://…/?sala=KWET7`);
  - solo el código (`KWET7` o `kwet7`);
  - el código con espacios o guiones.
- Saca el código con una expresión regular y lo pasa a mayúsculas.
- En el `.exe`, un botón **PEGAR** que lee el portapapeles.

**Abajo:** CONTRA BOTS · **SIN INTERNET (EN CLASE)** (lo de 14c) · MENÚ.

**Errores**, en una línea, con qué hacer:

| Caso | Mensaje |
|---|---|
| No existe la sala | "Esa sala no existe o ya se ha cerrado. Pide un enlace nuevo." |
| La partida ya ha empezado | "La partida ya ha empezado. Espera a la siguiente o crea tu sala." |
| Sala llena | "Sala llena (4/4)." |
| Versión distinta | En la web no pasa, porque siempre es la última. En el `.exe`: "Hay una versión nueva. Descárgala aquí", con botón que abre `web_url + "/descargar/VoodooCombo-Windows.zip"` |

## 15d · INVITAR y enlaces que te meten en la sala

Tiene que quedar como `docs/media/invitar_referencia.png`.

**En el lobby, arriba a la izquierda:**
- **SALA KWET7** en grande y un botón **INVITAR** grande en brasa;
- **al pulsarlo:** se copia al portapapeles y sale "Enlace copiado" durante 2 s. Se copia este texto:
  ```
  ¡Te reto a VoodooCombo!
  Entra aquí y apareces en mi sala:
  https://voodoocombo.duckdns.org/?sala=KWET7
  ```
- **En la web, si el navegador lo permite** (`navigator.share`), abre el menú de compartir del móvil u ordenador. Si no, copia.

**Abrir un enlace en la web** (`?sala=KWET7`):
1. Al arrancar, lee el parámetro con `JavaScriptBridge.eval("new URLSearchParams(location.search).get('sala') || ''")`.
2. Si hay sala:
   - pantalla corta "Entrando en la sala KWET7…";
   - si no tiene nombre, primero "¿Cómo te llamas?";
   - luego conecta y entra **directamente al lobby de esa sala**, sin pasar por el menú.
3. Quita el parámetro de la URL (`history.replaceState`), para que recargar la página no te vuelva a meter.
4. Si la sala no existe, el mensaje de 15c y el botón **CREAR MI SALA**.

**En el `.exe`:** pegar el enlace en UNIRSE (15c).

**Salas privadas:** las creadas con CREAR SALA **no salen** en PARTIDA RÁPIDA. Solo se entra con el enlace o el código.

## 15e · Partida rápida

- **Servidor**, nueva acción `quick(mode)`:
  - te mete en la sala pública de ese modo que lleve más tiempo esperando, que esté en `lobby` y no esté llena;
  - si no hay ninguna, crea una sala pública.
- **Lobby de una sala pública:**
  - arriba pone "Buscando jugadores… 0:12" en vez de INVITAR (también se puede invitar);
  - **empieza solo:**
    - cuando hay 4 humanos;
    - o a los **30 s** si hay al menos 2 humanos (se rellena con bots);
    - o con el botón **EMPEZAR CON BOTS**, que aparece a los 10 s si estás solo.
  - Al empezar se marcan todos listos automáticamente.
- Al acabar la partida, ¡OTRA! vuelve a la misma sala pública.
- **Tests:**
  - 2 clientes con `quick("voodoo")` acaban en la misma sala;
  - un tercero con `quick("greed")` acaba en otra sala.

## 15f · Reconexión automática

Si se corta el wifi un momento o el móvil se bloquea, no se puede perder la partida.
- **Al entrar en una sala,** el servidor da un `token` aleatorio. El cliente lo guarda en memoria y en `user://reconexion.json` junto al código de la sala.
- **Si se cae la conexión en lobby o en partida:**
  - el servidor **guarda el hueco 20 s**: el muñeco se queda quieto y sale "Reconectando…" encima;
  - el cliente reintenta cada 2 s, con un cartel "Reconectando… (3)". Con `rejoin(code, token)` recupera su jugador (`peer_id` nuevo, mismo índice en `MatchSim`) y sigue.
- **A los 20 s** sin volver, se hace lo de ahora: "puff" y la partida sigue.
- **En la web,** si recargas la página dentro de esos 20 s, vuelves a la sala con el token guardado.
- **Test:** un cliente se desconecta 5 s en mitad de la partida y vuelve. Tiene la misma puntuación y el mismo personaje, y la partida no se ha parado.

## 15g · La versión web

**Preset "Web"** en `export_presets.cfg`:
- `variant/thread_support=false`: no hace falta configurar cabeceras raras en el servidor;
- `html/canvas_resize_policy=2`;
- `html/focus_canvas_on_start=true`;
- `vram_texture_compression/for_desktop=true`;
- `include_filter="assets/**/*.json"`;
- `exclude_filter="docs/*, tools/*, build/*, deploy/*"`.

Claude lo probó con estos valores y exporta bien.

**Cambios con `OS.has_feature("web")`:**
- **Fuera:**
  - SALIR del menú;
  - tamaño de ventana;
  - "Alojar en mi PC" y "Partida en mi red" (el navegador no puede abrir servidores ni UDP);
  - abrir la carpeta de registros.
- **Pantalla completa:** botón y F11, con `DisplayServer.window_set_mode` tras un clic del usuario.
- **Primera pantalla "Pulsa para jugar":** el logo y "Pulsa cualquier tecla o haz clic". Los navegadores no dejan sonar el audio hasta que el usuario toca algo. Claude lo vio en la consola: `The AudioContext was not allowed to start`.
- **En el menú,** un enlace "Descargar para Windows", que lleva a `/descargar/VoodooCombo-Windows.zip`.
- **Rendimiento:**
  - tiene que ir a 60 fps en Chrome en un portátil normal, en una partida con 4 bots;
  - si no llega, baja partículas y efectos con `OS.has_feature("web")`;
  - mide los fps y apúntalos en la bitácora.
- **Guardado:** `user://` en la web va al almacenamiento del navegador. El perfil (nombre, nivel, cosméticos) se guarda igual que en el `.exe`.
- **El teclado tiene que funcionar nada más cargar** (el canvas tiene el foco). Las flechas y el espacio no tienen que hacer *scroll* en la página.

## 15h · Probar en local y entregar

**Prueba local completa sin Oracle**, igual que la hizo Claude:
1. `godot --headless --path . -- --server --ws --bind 127.0.0.1 --port 7780`.
2. Exporta "Web" a `build/web/`.
3. Lanza Caddy con este `Caddyfile` (`caddy run`):
   ```
   :8099 {
       handle /ws { reverse_proxy 127.0.0.1:7780 }
       handle { root * build/web
                file_server }
   }
   ```
4. Abre `http://localhost:8099` en dos navegadores. En local, sin HTTPS, la URL del servidor es `ws://localhost:8099/ws`.
5. Uno crea sala e invita, y el otro abre el enlace.

**Pruebas que tienen que quedar en la bitácora:**

| Prueba | Resultado esperado |
|---|---|
| Web + web, enlace de invitación | El segundo entra en la sala sin escribir nada |
| `.exe` + web, el `.exe` pega el enlace | Entra |
| Partida rápida con 2 clientes | Acaban juntos; a los 30 s empieza con bots |
| Desconectar el wifi 5 s en mitad de partida | Vuelve solo, con la misma puntuación |
| Recargar la página en el lobby | Vuelve a la misma sala |
| Servidor apagado | "Servidor en mantenimiento", y contra bots funciona |
| Partida completa en la web | Sin `SCRIPT ERROR` en la consola del navegador (F12) y a 60 fps |

**Al acabar:**
- sube los cambios a GitHub;
- en 10 minutos el servidor se actualiza solo. Comprueba que `https://<dominio>` ya enseña el juego y apúntalo en la bitácora.
- Si tarda, un humano puede forzarlo con `sudo /opt/voodoocombo/actualizar.sh` (ver `docs/SERVIDOR-ONLINE.md`).
