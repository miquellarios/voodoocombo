# Fase 13 — Pulir lo que está verde y ejecutable para probar online

> **Para Codex.** Antes de empezar:
> 1. La fase 12 tiene que estar terminada (ya lo está: commit `416631e`).
> 2. **Copia `docs/codex/fase-13/AGENTS.md` a la raíz como `AGENTS.md`.** Cambia §2 (Ejecutable), §6 (textos en partida y hechizos), §7 (HUD) y §8 (ajustes).
> 3. Mira las capturas de cómo está ahora en `docs/capturas/fase-12/`. Las sacó Claude ejecutando el juego, y abajo cada bloque dice qué captura enseña el fallo.
>
> Referencias de cómo tiene que quedar, en `docs/media/`:
> - `ajustes_referencia.png`: ajustes;
> - `hechizos_efectos_referencia.png`: efectos de hechizos.
>
> El arte nuevo ya está en `assets/ui/efectos_hechizos.png` (con su `.json`).

## Qué encontramos al probar la fase 12

Lo dicen Miquel y Joel, y Claude lo ha comprobado en el código y en las capturas:

1. **Ajustes:** casi ningún botón funciona bien al hacer clic.
   - La escala de la interfaz solo sube y no se puede bajar.
   - Los interruptores de destellos y vibración van mal, y al activarlos y desactivarlos el juego se pone en catalán.
2. **No hay ejecutable** para pasar a otros y probar el online.
3. **La taquilla se ve muy mal:** textos encima de otros textos y desplegables de sistema en los emotes.
4. **En partida hay demasiados números y textos a la vez:** agobian y se tapan entre ellos.
5. **Los hechizos no se ven al lanzarlos.** Solo cambia la ranura y sale un texto.
6. **Los modos de juego "no están":** existen, pero el selector está escondido.
7. **En general está verde:**
   - la pantalla de carga;
   - el podio;
   - la barra de progreso;
   - una tarjeta vacía en partida;
   - textos que no pasan por I18n.

## Cómo trabajar esta fase

- Son 10 bloques (**13a-13j**). Hazlos en orden, con **un commit por bloque** (`Fase 13a: <resumen>`).
- **Prioridad:** 13a (ajustes) y 13b (ejecutable) primero, porque el equipo quiere probar online ya.
- **Después de cada bloque de interfaz:**
  - saca una captura de la pantalla tocada a 1280×720 y a 1920×1080, con la escala al 75 %, 100 % y 130 %;
  - guárdalas en `docs/capturas/fase-13/`;
  - comprueba tú mismo que no hay textos encima de otros.
- Todos los números nuevos van en `GameConfig` y todos los textos por `I18n` (es, ca y en).

---

## 13a · Ajustes que funcionen (con flechas a los dos lados)

**Cómo está ahora** (`docs/capturas/fase-12/ajustes.jpg`, `_build_settings()` en `scenes/main/main.gd`):
- Cada opción es un botón que **da vueltas** al pulsarlo. Por eso la escala va de 100 a 125, a 150 y vuelta a 100, y **no se puede bajar**.
- Los botones miden 340×54, pero el texto ("TAMAÑO DE VENTANA: 1920×1080") es más ancho. **Al hacer clic en la parte del texto que sobresale no pasa nada.** Por eso "no funciona ningún botón".
- La escala solo agranda la letra de algunos `Label` y `Button` (`roundi(size * Settings.ui_scale)`). Las cajas no crecen, así que a 125 % y 150 % todo se solapa (`docs/capturas/fase-12/` → `s150`).
- Los `CheckButton` de destellos y vibración están sueltos en la esquina izquierda (x = 35), pequeños y con otra letra.
- **Catalán:** no lo hemos podido reproducir en Linux. Reprodúcelo en el ejecutable de Windows a 1920×1080, con la escala a 125 % y 150 %, activando y desactivando los dos interruptores con el ratón y con el teclado.
  - Lo más probable es que el clic o la tecla acabe en el botón de **Idioma**, que también da vueltas (es → ca → en).
  - Con el diseño nuevo desaparece, pero añade un test: cambiar cualquier ajuste que no sea Idioma no cambia `I18n.language`.

**Cómo tiene que quedar** (`docs/media/ajustes_referencia.png`):
- **Pantalla nueva** `scenes/settings/settings_view.gd` (sácala de `main.gd`).
- **Pestañas arriba:** PARTIDA · PANTALLA · SONIDO · ONLINE.
- **Cada opción es una fila** de 1080×84 px: nombre a la izquierda, y a la derecha **‹ valor ›** con dos flechas clicables.
  - Toda la fila tiene foco.
  - Con el teclado o el mando: izquierda y derecha cambian el valor; arriba y abajo cambian de fila.
  - El valor cambia al momento y **se guarda solo**. No hay botón de guardar.
  - Al cambiar, el valor hace un *pop* pequeño y suena un *tic*.

| Pestaña | Fila | Valores |
|---|---|---|
| PARTIDA | Escala de la interfaz | 75 · 85 · 100 · 115 · 130 · 150 %, con puntitos debajo para ver dónde estás |
| | Reducir movimiento | NO / SÍ |
| | Reducir destellos | NO / SÍ |
| | Vibración del mando | SÍ / NO |
| | Idioma | ESPAÑOL / CATALÀ / ENGLISH (los nombres en su idioma, no "es") |
| PANTALLA | Modo | VENTANA / PANTALLA COMPLETA |
| | Tamaño de ventana | 1280×720 · 1600×900 · 1920×1080 (gris si estás en pantalla completa) |
| SONIDO | Música | Barra de 0 a 100 con ‹ › de 10 en 10, y también se puede arrastrar |
| | Efectos | Igual, y suena un *tic* de prueba al soltar |
| ONLINE | Servidor | ESTE PC / RED LOCAL / ORACLE |
| | Dirección IP | Campo de texto, editable si no es ESTE PC |
| | Puerto | 7777 (solo se ve) |

- **La escala de la interfaz escala de verdad:**
  - aplica `Settings.ui_scale` como `content_scale_factor` de la ventana (`get_window().content_scale_factor`) o como `scale` del `hud_root` con pivote en el centro;
  - **todas** las pantallas: menús, lobby, HUD de partida, podio;
  - quita los `roundi(size * Settings.ui_scale)` repartidos por el código;
  - a 150 % nada puede salirse de la pantalla: si hace falta, el contenido de los menús va en un `ScrollContainer`.
- **Usa contenedores** (`VBoxContainer`, `HBoxContainer`, `MarginContainer`) en vez de posiciones fijas, para que los textos largos (catalán e inglés) no se salgan.
- Los botones del menú usan `custom_minimum_size` y `size_flags`, nunca un `size` fijo más pequeño que su texto.
- Pausa (Esc en partida): además de CONTINUAR y MENÚ, un botón **AJUSTES** que abre esta misma pantalla encima.

**Tests:**
- La escala sube y baja con las dos flechas y se guarda.
- Cambiar destellos o vibración no cambia el idioma.
- Las 6 escalas no dejan ningún `Control` fuera de 1280×720.

## 13b · Ejecutable para probar online, y alojar desde el juego

El equipo quiere pasar el juego a otras personas y jugar online **ya**, antes de tener Oracle. Ahora mismo hay que arrancar el servidor a mano con `--headless -- --server`, y la IP está escondida en AJUSTES → SERVIDOR.

**En el juego, pantalla JUGAR ONLINE:**
- **CREAR SALA EN ESTE PC** (nuevo):
  - lanza el servidor dedicado como proceso aparte, desde el mismo ejecutable: `OS.create_process(OS.get_executable_path(), ["--headless", "--", "--server", "--port", "7777"])`;
  - espera a que acepte conexiones (como mucho 5 s, reintentando), se conecta a `127.0.0.1` y crea la sala.
- **Mientras alojas**, arriba sale "Estás alojando · Tu IP: 192.168.1.23", con **COPIAR**:
  - la IP sale de `IP.get_local_addresses()`, la primera IPv4 privada, sin 127.x ni 169.254.x;
  - con un enlace "¿Jugar desde otra casa?" que abre una ayuda corta (abajo).
- **UNIRSE:**
  - campo **IP del anfitrión**, que recuerda la última;
  - campo **código de sala**;
  - botón **ENTRAR**.
  - Si la IP está vacía, usa la de AJUSTES → ONLINE.
- **CONTRA BOTS**, como ahora.
- **Al cerrar el juego o salir de la sala siendo anfitrión:** mata el proceso del servidor (`OS.kill(pid)` en `NOTIFICATION_WM_CLOSE_REQUEST` y al salir), y avisa a los demás con el cartel de desconexión.
- **Si no conecta en 6 s:**
  - "No se ha podido conectar a <IP>. ¿Está abierto el juego del anfitrión y el puerto UDP 7777?";
  - nunca se queda colgado en "Conectando…".
- **Versión:**
  - se ve abajo a la derecha en el menú (`v0.13.0`);
  - si no coincide, el error dice las dos: "Tu versión 0.13.0 · Servidor 0.12.1".

**Ayuda "¿Jugar desde otra casa?"** (texto en I18n, corto):
- En la misma red (clase, misma wifi): no hace falta nada.
- Desde casas distintas:
  - **Opción fácil:** instalad todos la misma VPN gratuita de juego en red (Radmin VPN, ZeroTier o Tailscale), entrad en la misma red y usad la IP que os da la VPN.
  - **Opción router:** el anfitrión abre el puerto **UDP 7777** hacia su PC.
- La primera vez, Windows pregunta por el firewall: hay que permitir **redes privadas**.

**Exportar** (lo hace Codex):
1. Instala las plantillas de exportación de **Godot 4.7.2**, las mismas que el motor. Se bajan de la página de versiones de Godot en GitHub.
2. `godot --headless --path . --export-release "Windows" build/VoodooCombo.exe`
3. Prepara `build/VoodooCombo-v0.13.0-Windows.zip` con:
   - `VoodooCombo.exe` y su `.pck` (o el `.pck` incrustado);
   - `LEEME.txt` en castellano: cómo crear sala, cómo unirse, lo de la VPN y el firewall;
   - `servidor.bat`, que arranca solo el servidor (`VoodooCombo.exe --headless -- --server --port 7777`) para un PC que haga de servidor sin jugar.
4. El zip pesa menos de 100 MB y **no se sube al repositorio**: `build/` va en `.gitignore`. Sube el zip como *release* de GitHub (`gh release create v0.13.0 build/VoodooCombo-v0.13.0-Windows.zip`), si tienes permiso. Si no, déjalo en `build/` y dilo en la bitácora.
5. Sube `NET_VERSION` y la versión del proyecto a `0.13.0`.

**Prueba** (apúntala en la bitácora):
- dos ejecutables en dos PCs de la misma red;
- uno aloja y el otro entra con IP y código;
- partida completa;
- el anfitrión cierra el juego y al otro le sale el aviso.

## 13c · Taquilla que se vea bien

**Cómo está ahora** (`docs/capturas/fase-12/taquilla.jpg` y `taquilla_emotes.jpg`):
- **CAMBIAR NOMBRE** está encima del nombre del jugador. Los dos usan la misma Y de `GameConfig`, más o menos.
- El personaje queda pequeño y medio tapado por las pestañas.
- Los marcos son iconos de 66 px casi iguales y no se distinguen.
- La pestaña Emotes son 8 `OptionButton` (desplegables de sistema) con "1 · Risa": se ve como un formulario.
- Al 125 % todo se pisa.

**Cómo tiene que quedar:**
- **Dos columnas:**
  - **Izquierda (40 %):**
    - el personaje en grande (unos 320 px), con la animación `idle` y **lo que llevas puesto**: marco detrás del retrato y estela animada detrás del muñeco;
    - debajo, el nombre del personaje (Cinzel), su rol (Oswald) y **tu nombre** con un lápiz ✎ al lado para cambiarlo;
    - flechas ‹ › a los lados del muñeco para cambiar de personaje.
  - **Derecha (60 %):** pestañas PERSONAJE · MARCO · ESTELA · EMOTES y una rejilla de tarjetas de 160×180.
    - Cada tarjeta lleva el icono grande (110 px), el nombre debajo y, si está bloqueada, un candado y "Nivel N" en gris.
    - La equipada lleva un borde de brasa y una marca ✓.
    - **Al pasar el ratón o el foco por una tarjeta, se ve puesta en el muñeco de la izquierda** (vista previa), aunque esté bloqueada.
- **Pestaña EMOTES:**
  - arriba, la **rueda de 8 huecos** dibujada como en partida;
  - al hacer clic en un hueco, se ilumina y abajo sale la rejilla con todos los emotes, bailes y gritos (iconos, no desplegables);
  - al elegir uno, va a ese hueco;
  - los gritos se ven como una tarjeta con el texto del grito en pequeño.
- **Escala:** todo en contenedores. A 75-150 % nada se pisa.

## 13d · Menos números y menos texto en partida: dopamina con movimiento

**Cómo está ahora** (`docs/capturas/fase-12/j15.jpg`, `j85.jpg` y `greed.jpg`):
- Sale "+1" / "+2" por **cada doblón de cada jugador**: con 4 jugadores, decenas a la vez.
- "¡Combo!" de **cualquier** jugador sale en el mismo sitio fijo (`COMBO_NOTICE_POSITION`), como si fuera tuyo.
- Cada vez que alguien abre un cofre, sale el nombre del hechizo en dorado y grande ("Alfiler Vudú"), aunque sea de un bot.
- Al final de la partida se amontonan "¡Zas! ¡ROBO! -8 +2 Alfiler Vudú" uno encima de otro.
- Encima de cada muñeco: nombre, "TÚ · Miquel", la forma, el círculo de combo con dos números, y en Codicia otro número más.
- Arriba, 4 fichas con 4 números grandes de colores.
- Hay textos en **dorado** (`GameConfig.GOLD`), cuando la regla de "Brasa minimal" es hueso y brasa.

**Reglas nuevas** (van en `AGENTS.md` §6, versión de la fase 13):

1. **Solo ves textos que te importan:**
   - lo tuyo (lo que coges, tu combo, tu hechizo);
   - lo que te hacen a ti (te roban, te golpean);
   - lo que haces a otros (robas, golpeas).
   - De los demás jugadores: **ningún texto**, solo chispas y sonido.
2. **Como mucho 3 textos en pantalla a la vez:**
   - si sale un cuarto, el más viejo desaparece al momento;
   - los textos **nunca se tapan**: si hay uno en el mismo sitio, el nuevo sale 36 px más arriba.
3. **Contador de racha en vez de "+1" sueltos:**
   - mientras encadenas doblones, **un solo número** junto a tu muñeco que va sumando: "+1 → +2 → +4 → +7…";
   - en cada doblón hace *pop* y sube de tamaño poco a poco (de 28 a 40 px);
   - cuando la racha acaba, ese número **vuela a tu ficha del marcador**, que hace *pop* y cuenta hacia arriba;
   - así, en vez de 10 textos, hay 1 que crece. Es la sensación de "máquina tragaperras", que es la dopamina buena.
4. **Los avisos grandes** ("¡VOODOO COMBO!", "¡FRENESÍ!", "¡LA NIEBLA SE CIERRA!"):
   - uno cada vez, en el centro arriba, con cola si coinciden (0,3 s entre uno y otro);
   - "¡Combo!" (x2) ya no es aviso grande: es el contador del punto 3 cambiando a brasa con un temblor;
   - "¡VOODOO COMBO!" solo si es **tuyo**.
5. **Hechizos:** sin texto de nombre al abrir el cofre. Lo tuyo lo explica la tarjeta de la ranura (13e); lo de los demás, el efecto visual (13f).
6. **Encima de cada muñeco:**
   - los rivales llevan su forma de color (● ▲ ■ ◆) y el nombre **solo los primeros 3 s** de la partida y cuando ganan la corona (1,5 s);
   - tú, la flecha y el aro de siempre, sin "TÚ · nombre" fijo;
   - el círculo de combo, solo con "x2" / "x3", sin el segundo número.
7. **Marcador:**
   - **tu ficha** más grande y siempre a la izquierda; las de los rivales, más pequeñas (número de 22 px);
   - el líder lleva la corona;
   - al cambiar de posición, las fichas se reordenan con un deslizamiento de 0,25 s.
   - En Codicia, los dos cofres del equipo arriba en el centro y las fichas sin número grande.
8. **Colores:**
   - los textos de partida, solo de la tabla de `AGENTS.md` §7: hueso, brasa, rojo, cian y morado;
   - quita `GameConfig.GOLD` de todos los textos; el dorado queda solo para los doblones dibujados.

**Prueba:** graba 20 s de partida con 4 bots. Nunca tiene que haber más de 3 textos a la vez, ni dos textos encima.

## 13e · Ranura del hechizo y tarjeta

- **La tarjeta que sale al coger un hechizo está vacía** (`docs/capturas/fase-12/greed.jpg`, abajo a la izquierda: un rectángulo con borde dorado sin nada dentro). `SpellNotice` se hace visible pero su icono, nombre y texto no se ven. Arréglalo:
  - icono de 64 px, nombre en Cinzel brasa y una frase en Oswald hueso;
  - "Pulsa E" con la tecla dibujada (`tecla_e.png` / `tecla_b.png`).
- **Ranura vacía:** sin la palabra "HECHIZO", solo el aro apagado.
- **Con hechizo:** el icono late y debajo sale la tecla. Si es de duración, el aro se vacía con el tiempo restante, sin números con decimales ("3.4").

## 13f · Los hechizos se ven al lanzarlos

Referencia: `docs/media/hechizos_efectos_referencia.png`. Sprites: `assets/ui/efectos_hechizos.png`.
- Tira de 10 frames de 192×192, que se dibujan a 0,5.
- El orden está en `efectos_hechizos.json`: `oveja_a`, `oveja_b`, `hielo`, `capa`, `iman`, `botas`, `anillo`, `alfiler`, `lanzar`, `escarcha`.
- El centro del frame es el centro del muñeco: su posición menos 40 px en y.

**Ahora** no hay nada:
- `item_used` llega a la vista pero `_handle_events()` no hace nada con él;
- la oveja no se dibuja (el líder sigue igual, solo va lento);
- la escarcha no se ve;
- **el alfiler golpea al instante al rival más cercano**, sin proyectil. Eso va contra `AGENTS.md` §4.4: "proyectil a 700 px/s con 900 px de alcance hacia donde miras".

**Al pulsar E**, para todos los hechizos:
1. **Círculo de runas** (`lanzar`) bajo los pies del que lanza: entra con escala 0,4 → 1,1 → 1 en 0,25 s y se desvanece.
2. **El icono del hechizo** (de `hechizos.png`) sale del muñeco, sube 40 px y se desvanece en 0,5 s.
3. Un sonido propio de cada hechizo (sintetizado).
4. Si lo lanzas tú: un parpadeo suave del borde de la pantalla del color del hechizo, que respeta "Reducir destellos".

**Efecto propio de cada hechizo:**

| Hechizo | Mientras dura / al impactar |
|---|---|
| Imán | `iman` girando despacio alrededor del muñeco. Los doblones atraídos vuelan en espiral con una estela dorada fina |
| Botas | `botas` detrás del muñeco, según hacia dónde se mueve, y 3 copias fantasma del sprite que se desvanecen (como en la referencia) |
| Capa | `capa` alrededor del muñeco, latiendo. Al bloquear algo: se rompe en 10 cristales cian que salen volando, con un "¡clin!" |
| Alfiler | **Proyectil de verdad** (`alfiler`) hacia donde miras, a 700 px/s, alcance 900 px. Choca con obstáculos y bordes. Al impactar: golpe normal. Lógica en `MatchSim`, con el proyectil en el snapshot para la red |
| Escarcha | Onda (`escarcha`) que crece de 0 a 180 px en 0,3 s. Cada rival congelado lleva `hielo` encima 1,5 s y al acabar se rompe en cristales |
| Oveja | Rayo morado en arco del que lanza al líder (0,6 s, como el tiempo que tarda), una nube de humo blanca y el líder **se dibuja como la oveja** (`oveja_a` / `oveja_b` alternando a 6 fps al moverse) durante 3 s. Al acabar, otra nube y vuelve |
| Anillo | `anillo` detrás del muñeco, girando, con destellos. Cada doblón que coges con él hace una chispa dorada extra |

- **Todo esto se ve en todos los clientes**, porque sale de los eventos y del snapshot. No hace falta texto para saber quién ha lanzado qué.
- **Bots:** igual que los humanos.
- **Tests:**
  - el alfiler crea un proyectil que avanza 700 px/s y desaparece al chocar con un obstáculo;
  - un jugador convertido en oveja tiene `item == "sheep"` en el snapshot durante 3 s.

## 13g · Los modos, a la vista

**Ahora:**
- Los tres modos existen (`GameConfig.MODES`).
- Pero el selector es un botón de texto arriba a la derecha del lobby, que pone "voodoo combo" y da vueltas al pulsarlo (`online_lobby.gd`, `mode_button`). No parece un botón y no se entiende (`docs/capturas/fase-12/lobby_bots.jpg`).

**Cómo tiene que quedar:**
- **Pantalla ELIGE MODO** después de JUGAR (tanto online como contra bots), antes del lobby:
  - **3 cartas grandes** (360×460), una por modo;
  - cada carta tiene un dibujo hecho con el arte que ya hay:
    - doblones y combo para VoodooCombo;
    - costuras para Último en Pie;
    - los dos cofres de equipo para Codicia;
  - el nombre en Cinzel, las 3 líneas de reglas y los jugadores (2-4, o 2 contra 2);
  - foco con brasa;
  - si eres anfitrión, eliges y entras; si te unes a una sala, esta pantalla no sale.
- **En el lobby:** arriba en el centro, una **tarjeta del modo** con ‹ › que solo cambia el anfitrión, con su icono y las 3 líneas. A los demás les sale "Elige el anfitrión".
- **Contra bots:** en el lobby no tiene sentido "CÓDIGO DE SALA —" ni COPIAR. Quítalos y pon "PARTIDA CONTRA BOTS".
- **Pantalla de carga:** enseña las reglas **del modo elegido** (12l no lo hace: en Codicia sale lo de VoodooCombo, `carga_greed`).
- **Último en Pie** (`docs/capturas/fase-12/survival.jpg`):
  - las costuras de cada ficha son unas "x x x" diminutas que no se leen; usa `costuras.png` a 28 px;
  - encima de cada muñeco, sus costuras a 18 px.

## 13h · Pantalla de carga y podio

**Pantalla de carga** (`docs/capturas/fase-12/carga.jpg`):
- **Ahora:** la miniatura de la arena es pequeña, sobra mucho espacio vacío, la frase de una trampa queda tapada por el retrato del jugador y la barra de carga es una pastilla gris que no se llena.
- **Cómo tiene que quedar:**
  - la arena grande arriba (60 % del ancho);
  - las trampas en una columna a la derecha, sin tocar el retrato;
  - abajo, en una fila: tu personaje, el consejo, los 3 retos y la barra.
- **Barra de carga:**
  - `ProgressBar` con `StyleBoxFlat` propios: fondo `#241838` y relleno brasa, de 600×10 px;
  - o una barra dibujada con un alfiler que avanza.
  - Arregla también la barra de XP del podio, que tiene el mismo fallo.

**Podio** (`docs/capturas/fase-12/podio.jpg`):
- **Ahora:**
  - la placa del 3º tapa el "3º";
  - el 4º queda con la placa flotando y el muñeco detrás;
  - MENÚ PRINCIPAL y ¡OTRA! quedan pegados abajo, en pequeño y encima del podio.
- **Cómo tiene que quedar:**
  - las placas van **debajo** de cada bloque, sin tapar el número;
  - el 4º, de pie en el suelo a la derecha con su placa debajo;
  - los botones en una fila propia, abajo del todo, con margen de 40 px;
  - la barra de XP, debajo del título, de 500 px y sin el texto "20%" suelto.

## 13i · Repaso general

- **Textos fijos en castellano en el código que no pasan por I18n:**
  - "WASD mover · Espacio dash · E hechizo · Esc atrás" en el menú;
  - "PAUSA" y "Continuar";
  - "Aún no hay partidas guardadas".
  - Busca `"` con letras en `scenes/` y `ui/`, y pásalo todo a I18n.
- **Historial:** `if y == 170.0` nunca se cumple (y empieza en 202), así que nunca sale "Aún no hay partidas". Arréglalo.
- **Modo del historial:** sale "voodoo", "greed"… Usa el nombre del modo traducido.
- **`GameConfig.GOLD`** se sigue usando como color de títulos y textos en muchos sitios (`_label` lo cambia a hueso a escondidas). Quítalo de la interfaz y usa `BONE_TEXT` o `EMBER`.
- **Snapshot de red:** manda `hazard_runtime`, `chest_fade_alpha` y otros datos 20 veces por segundo aunque no cambien. Mide los bytes por snapshot con 4 jugadores y apúntalo en la bitácora. Si pasa de 1,5 KB, manda solo lo que cambia.
- **Menú principal:** la versión pequeña abajo a la derecha (13b).

## 13j · Cerrar

- Actualiza `AGENTS.md` con lo que hayas cambiado (ya viene casi todo en la versión de la fase 13).
- Ejecuta todos los tests en headless.
- En `docs/BITACORA.md`, una entrada por bloque con **qué tenemos que probar**:
  - cada fila de ajustes, con ratón, teclado y mando, a 75 % y 150 %;
  - alojar y unirse por IP desde dos PCs;
  - la taquilla en las 4 pestañas;
  - una partida con 4 bots: como mucho 3 textos a la vez;
  - cada hechizo, viendo su efecto;
  - los 3 modos desde la pantalla ELIGE MODO;
  - la pantalla de carga y el podio con 2, 3 y 4 jugadores.
- Deja las capturas de `docs/capturas/fase-13/` para que Claude las revise.
