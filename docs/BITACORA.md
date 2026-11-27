# Bitácora de desarrollo

## Registro de Codex

### Fase 14b — cola de entrada y snapshots de un paquete
- El servidor encola hasta seis entradas por jugador, aplica una por tick y dos cuando hay más de tres acumuladas; repite la última dirección hasta 0,25 s y el `ack` solo avanza cuando esa secuencia se aplica. Dash y hechizo conservan su intención fiable.
- Los snapshots comprimen los campos visibles de jugadores, excluyen campos internos y refrescan doblones al cambiar o cada segundo. Ping usa el canal 3 no fiable; la interpolación se adapta entre 100 y 160 ms por jitter, la corrección usa 0,2/0,1 s y los dashes solo saltan por encima de 96 px. La predicción incluye cinta y lodo. El HUD señala pérdida de snapshots superior al 5 %.
- Godot 4.7.2 pasó cola/timeout, codec y prueba de red de tres procesos con 30 s de movimiento, 0–60 ms de jitter y 5 % de snapshots omitidos: error medio reconciliado 1,11 px (30/600 omitidos). Cuatro arenas y cuatro jugadores dieron 841–847 B comprimidos; el servidor registró un máximo de 947 B en la partida ENet.
- La prueba multiproceso existente llegó a completar la partida y todos los clientes imprimieron `MATCH PASS`; su script no aporta un código de salida legible en este entorno y el endpoint HTTP no pudo enlazar el puerto 8080. La prueba específica 14b evita ese puerto y sí concluyó.
- Humanos: jugar con dos PCs en wifi y repetir con VPN; validar continuidad del movimiento, interpolación, indicador de ping/pérdida y que la cinta mueve al jugador predicho.

### Fase 14a — cierre del bucle de racha y textos acotados
- Copiada la fuente de verdad de fase 14 a `AGENTS.md` y archivados el enunciado, sus capturas de referencia y la imagen de conexión online.
- `_finish_pickup_streak()` ahora guarda y reinicia su estado antes de crear UI, calcula el destino con coordenadas de `Control`, limita las etiquetas del HUD a 12 y vacía la racha al acabar la partida. El marcador actualiza el valor local aunque la racha siga activa. `Fx` también recorta su cola a 12 textos y se avisa una sola vez si el árbol de nodos crece más de 500 durante la partida.
- `tests/test_local_match.gd` ejercita 90 segundos con recogidas locales, controla que el HUD no añada más de 40 hijos en 30 segundos, comprueba que marcador y jugador coinciden y estresa el límite de textos. Godot 4.7.2 pasó la prueba sin `SCRIPT ERROR`.
- Humanos: repetir una partida de 90 s contra tres bots recogiendo doblones; comprobar que el marcador local avanza mientras el contador de racha sigue visible y que el juego no acumula textos ni se ralentiza.

### Fase 13g — Selector de modo visible
- Añadida una pantalla de tres tarjetas ilustradas antes de crear una sala online o una partida contra bots; unirse por código sigue entrando directamente. El modo elegido viaja en la solicitud de sala y se conserva en el directorio local.
- El lobby muestra la tarjeta del modo y deja cambiarla al anfitrión; los invitados ven que debe elegir el anfitrión. La práctica local ya no muestra código ni botón de copiar. Se ampliaron las costuras del marcador a 28 px y las que aparecen sobre los personajes a 18 px.
- Pasaron `tests/test_lobby_view.gd`, `tests/test_rooms.gd` y `tests/run_tests.gd` con Godot 4.7.2. La prueba ENet de varios procesos no se pudo completar dentro del aislamiento local en el intento previo; se repetirá con permiso de sockets locales. No se validó visualmente esta pantalla mediante captura.
- Humanos: probar las tres tarjetas con ratón, teclado y mando; crear partidas de bots y salas online en cada modo; verificar cambio de modo solo por el anfitrión, entrada directa por código y legibilidad de las costuras.

### Fase 13h — Carga y podio
- Recompuesta la carga: miniatura grande, trampas en columna, personaje/consejo/retos abajo, reglas del modo elegido y barra de carga con relleno brasa. La barra de XP del podio también tiene estilos propios y oculta el porcentaje automático.
- Las placas pasan debajo de los bloques, el cuarto personaje y su placa se colocan a la derecha y los botones comparten una fila inferior con 40 px de margen. Pasaron la suite core, `test_local_match.gd` y `test_full_modes.gd`.
- No pude verificar el aspecto con captura gráfica en modo headless; queda revisión visual humana en las resoluciones previstas.
- Humanos: revisar la carga de los tres modos en los cuatro mapas, barra de progreso y retos; revisar podio con 2, 3 y 4 jugadores, que el ordinal permanezca visible y que placa, medallas y botones no se solapen.

### Fase 13i — Auditoría general y snapshots
- El texto de controles del menú y el aviso de historial vacío ahora pasan por I18n en español, catalán e inglés; el historial muestra el nombre localizado del modo y detecta correctamente cero partidas. Los títulos, contador y marco de voto usan hueso/brasa en lugar de dorado de interfaz.
- Medidos snapshots reales preparados para red con cuatro jugadores en las cuatro arenas. El máximo fue 1.526 B comprimidos (Biblioteca), por debajo de 1,5 KiB/1.536 B. `SnapshotCodec` omite campos de servidor y empaqueta estados visuales activos de raíces/barril; el cliente los restaura al formato de dibujo.
- Godot 4.7.2 escaneó el proyecto sin errores de scripts. Pasaron la suite core, integración local, partidas completas en los tres modos, medición de snapshots y prueba ENet de cuatro clientes más un quinto rechazado en VoodooCombo, Último en Pie y Codicia; los clientes coinciden en resultados y `/results` anuncia el modo correcto.
- Humanos: abrir Historial sin partidas y con resultados de cada modo en es/ca/en; revisar la paleta hueso/brasa y validar trampas de raíces/barril sincronizadas entre clientes durante una partida real.

### Fase 13a — Ajustes y accesibilidad
- Reemplazada la pantalla antigua por `scenes/settings/settings_view.gd`, con pestañas de partida, pantalla, sonido y online. Las opciones persistentes usan flechas clicables, foco, campos numéricos/servidor y controles de audio; el tamaño de ventana queda inactivo en pantalla completa. Ajustes se abre también desde pausa.
- Incorporadas las referencias y assets de fase 13, y actualizado el `AGENTS.md` de raíz según el paquete entregado. La escala de ajustes adapta controles y tipografía; el contenido de opciones puede desplazarse verticalmente a escalas altas para conservar el área de lectura.
- Añadidas pruebas de persistencia de escala al subir y bajar, y de que accesibilidad no cambia el idioma. `tests/run_tests.gd` pasa en Godot 4.7.2. Capturas de las cuatro pestañas a 1280×720 y 1920×1080, con escalas 75 %, 100 % y 130 %, en `docs/capturas/fase-13/`.
- Pruebas humanas pendientes: ratón, teclado y mando a 75 % y 150 %; probar ventana/pantalla completa, audio y el retorno desde pausa. No se ha probado todavía el tamaño de ventana en un monitor real.

### Fase 13b — Servidor local y ejecutable de prueba
- Añadido «Crear sala en este PC»: inicia el servidor dedicado desde el ejecutable, reintenta la conexión local hasta 5 s y termina el proceso al cerrar o abandonar. La pantalla de conexión admite IP y código de sala, recuerda la IP, muestra la IPv4 privada al anfitrión, permite copiarla y explica cómo conectar desde otra casa. Se muestran las versiones del cliente y servidor cuando no coinciden, y el menú indica v0.13.0.
- Actualizados `NET_VERSION`, versión del proyecto y preset de Windows a 0.13.0, manteniendo los presets Linux existentes. Exportado `build/VoodooCombo.exe` con Godot 4.7.2; paquete `build/VoodooCombo-v0.13.0-Windows.zip` de 53,6 MB (PCK incrustado), con LEEME, servidor.bat y licencia. `build/` queda ignorado y los binarios antiguos se retiran del índice. No se pudo publicar un GitHub Release porque `gh` no está instalado ni hay un cliente de publicación disponible en este entorno; el ZIP queda local.
- La regresión completa de lógica pasa. Prueba local autorizada de loopback inicia el servidor, conecta un cliente y verifica que el proceso muere al salir. El ejecutable exportado arranca en modo headless. No se ha podido comprobar entre dos PCs ni verificar el firewall/NAT.
- Pruebas humanas: probar alojar y unirse por IP/código desde dos PCs en la misma wifi; repetir desde redes distintas con VPN, cerrar el anfitrión durante una partida y comprobar el aviso de desconexión.

### Fase 13c — Taquilla y cosméticos
- Reorganizada la taquilla en dos columnas: personaje animado, marco y estela equipados a la izquierda; tarjetas enfocables para personaje, marco y estela a la derecha. El foco y el ratón previsualizan el objeto; las tarjetas muestran selección y nivel de desbloqueo. La pestaña social ahora usa ocho ranuras en rueda y una cuadrícula, sin `OptionButton`. Los textos nuevos de personajes y estelas pasan por I18n en es/ca/en.
- Añadidas constantes de disposición/tamaño a `GameConfig`. Capturas de las cuatro pestañas en 1280×720 y 1920×1080, con 75 %, 100 % y 130 %, en `docs/capturas/fase-13/`. Revisadas visualmente varias esquinas de resolución/escala: tarjetas y nombres quedan separados; la cuadrícula de emotes continúa con scroll.
- La regresión principal pasa y una prueba temporal recorrió las cuatro pestañas sin desplegables. Esa prueba de reconstrucción repetida terminó con avisos de RIDs `CanvasItem`; dos cambios de pestaña aislados no los reprodujeron. Queda como prueba humana cambiar varias veces de pestaña en una sola sesión.
- Pruebas humanas: recorrer PERSONAJE, MARCO, ESTELA y EMOTES con ratón, foco/teclado y mando; previsualizar bloqueados, equipar uno disponible, configurar las ocho ranuras y revisar la taquilla a 75 % y 150 %.

### Fase 13d — Menos ruido visual en partida
- Quitados los textos repetidos por cada doblón y los nombres al abrir cofres; los avisos de combo y golpes ahora se atribuyen al jugador afectado. El jugador local ve una racha acumulada (+N) que aumenta de tamaño y vuela a su marcador al terminar.
- Limitados los textos flotantes a tres a la vez, con separación vertical mínima; los banners de Frenesí, Voodoo Combo y niebla se encolan. Sobre el muñeco local quedan la flecha, la forma y el aro; los nombres rivales solo aparecen al inicio y al ganar la corona. El marcador fija tu ficha a la izquierda, reduce el tamaño de números rivales, anima el reordenamiento y oculta las cifras individuales en Codicia.
- El escaneo de scripts de Godot 4.7 y `tests/run_tests.gd` pasan. La captura automática de este bloque no se pudo obtener con el renderer headless (no ofrece textura de pantalla); queda pendiente la revisión gráfica y la prueba de 20 s con cuatro bots.
- Pruebas humanas: jugar 20 s con cuatro bots y comprobar que nunca aparecen más de tres textos, que no se pisan, que la racha vuela al marcador, que los avisos grandes esperan su turno y que las fichas se reordenan bien en Codicia y VoodooCombo.

### Fase 13e — Ranura y tarjeta del hechizo
- La ranura vacía ya no muestra «HECHIZO» ni una tecla accionable. Al guardar un hechizo muestra el nombre, la tecla correcta y un pulso suave; los efectos de duración tienen un aro que se vacía sin contador decimal. La tarjeta de adquisición lleva icono de 64 px, título Cinzel en brasa, descripción Oswald en hueso y tecla E/B con texto localizado.
- Añadidas las cadenas «Pulsa / Prem / Press» y constantes de dimensión, pulso y aro. Godot 4.7 escanea los scripts y `tests/run_tests.gd` pasa; queda pendiente revisar la legibilidad de la tarjeta al 75 % y 130 % en ventana real.
- Humanos: recoger cada hechizo, comprobar la tarjeta, teclado y mando; activar los cuatro hechizos de duración y confirmar el vaciado del aro, la ranura vacía y el ajuste «Reducir movimiento».

### Fase 13f — Efectos visibles de los hechizos
- Añadida la secuencia de lanzamiento (runas, icono ascendente, sonido por hechizo y flash local accesible), auras de Imán/Botas/Capa/Anillo, fantasma de Botas, onda y estado congelado de Escarcha, arco y transformación de Oveja con humo, y cristales al romperse la Capa o terminar Escarcha.
- El Alfiler ahora es un proyectil autoritativo de 700 px/s y 900 px de alcance, con colisión contra hitboxes de obstáculos, bordes y rivales. `pin_projectiles` y las maldiciones ovinas en viaje forman parte del snapshot; Oveja tarda 0,6 s y luego convierte al líder durante 3 s. Se corrigió además el uso de Oveja, que se confundía con un hechizo de duración del lanzador.
- Tests nuevos comprueban creación, velocidad, snapshot y desaparición del Alfiler ante un obstáculo, así como el viaje y duración de Oveja. Escaneo de Godot 4.7, suite completa y prueba de integración local con HUD/aro pasan.
- Humanos: probar los siete hechizos en local y red, fijarse en proyectil y obstáculos, objetivo de Oveja, congelación, bloqueo de Capa, y los ajustes de reducir movimiento/destellos. La captura visual del bloque queda pendiente porque el renderer headless no permite extraer imágenes.

## Registro humano

Lo rellenáis vosotros después de cada fase. Son las preguntas que hace el profesorado.

| Fecha | Fase | Prompt (resumen) | ¿Funcionó a la primera? | Qué reformulamos y por qué | Qué investigamos por nuestra cuenta | ⭐ |
|---|---|---|---|---|---|---|
| | | | | | | |

## Momentos clave ⭐ (para la presentación)

-

## Registro de Codex

> Codex añade aquí una entrada por fase. Solo hechos reales: no se inventan problemas.

### Fase 9a — Movimiento y colisiones (13/11/2026)
- Qué se ha hecho: Añadida `ArenaPhysics` para desplazar círculos por ejes, deslizarse por obstáculos y separar jugadores sin atravesar la geometría. Jugador y bots usan la misma resolución de movimiento y el dash se detiene al chocar. Añadidas pruebas de deslizamiento y separación.
- Decisiones: Las colisiones se calculan con los rectángulos exactos de `arenas.json`; el radio de jugador viene de `GameConfig`.
- Problemas encontrados y cómo se resolvieron: Godot no registró la nueva clase global en la primera ejecución directa de tests; el escaneo headless del editor actualizó la caché de clases y después los tests pasaron.
- Qué tienen que probar los humanos: Moverse en diagonal contra los cuatro lados de varios obstáculos, cruzar esquinas y dejar dos personajes superpuestos para confirmar que se deslizan/separan y que el dash se corta contra los muros.

### Fase 9b — Rutas y antiatasco de bots (13/11/2026)
- Qué se ha hecho: Los bots buscan monedas y cofres con AStarGrid2D, recalculan la ruta cada 0,3 s, evitan casillas de pinchos activas, encarecen barriles y rayos, reparten objetivos entre bots y prueban una dirección de escape al detectar un atasco.
- Decisiones: Se inflan las celdas sólidas con el radio del jugador para que la ruta sea físicamente transitable, no solo libre en el centro de cada casilla.
- Problemas encontrados y cómo se resolvieron: El primer test tomó un camino que rozaba una esquina y el círculo no podía seguirlo; al incluir la huella de colisión en la cuadrícula, el bot llega al objetivo en menos de cinco segundos.
- Qué tienen que probar los humanos: Dejar bots en esquinas y alrededor de muros durante dos minutos y revisar que no se atasquen, que elijan cofres sin hechizo y que eviten pinchos, barriles y rayos.

### Fase 9c — Dash de bots y choques (13/11/2026)
- Qué se ha hecho: Los bots evalúan ataques cada 0,4–0,6 s, solo contra rivales visibles, cercanos, vulnerables y con dash disponible. Tras un golpe se bloquean 2,5 s; hay una pausa compartida entre bots para evitar cadenas. Dos dashes que chocan rebotan 70 px y bloquean el dash 0,3 s. El dash también se corta al chocar con un muro.
- Decisiones: Se prioriza el control de spam con una espera común de 2,5 s entre dashes de bots, manteniendo además el porcentaje de acierto del 30 % en cada decisión.
- Problemas encontrados y cómo se resolvieron: El test inicial superó el límite de cuatro dashes en diez segundos; una pausa compartida entre bots eliminó esa ráfaga y el test pasó.
- Qué tienen que probar los humanos: Dejar dos bots cerca durante diez segundos sin monedas próximas, observar choques entre dashes y confirmar que ninguno se queda haciendo dash repetidamente ni queda dentro del otro.

### Fase 9d — Trampas y golpes comunes (13/11/2026)
- Qué se ha hecho: Conectados los efectos del lodo, raíces, pinchos, fantasma, cintas, vapor, barriles, portales y rayo. Los golpes usan un cálculo común con doblones en abanico, combo perdido, aturdimiento, invulnerabilidad y bloqueo por Capa Élfica. Actualizadas las reglas en `AGENTS.md` y `assets/arenas/ARENAS.md`.
- Decisiones: Las trampas periódicas consultan `elapsed`; raíces y barriles usan estado de partida. Los efectos corren en la simulación local actual porque aún no hay una simulación de partida autoritativa integrada.
- Problemas encontrados y cómo se resolvieron: Godot detectó inferencias ambiguas en dos vectores; se declararon como `Vector2`. Los tests de reglas y el arranque headless de la escena pasaron.
- Qué tienen que probar los humanos: Probar cada trampa de las cuatro arenas, observar sus avisos/daños/caídas de doblones y repetir con Capa Élfica e invulnerabilidad activas.

### Fase 9e — Texturas de objetos y hechizos (13/11/2026)
- Qué se ha hecho: Integrados `assets/items/`; los doblones giran con desfases y bote sobre su sombra, los cofres tienen reposo y apertura animados, y los iconos de hechizo aparecen en la ranura y en la ruleta.
- Decisiones: Los tamaños, fps, escalas y tiras se leen desde `items.json`; la apertura dura 0,25 s y deja la ruleta del hechizo en sus 0,8 s existentes.
- Problemas encontrados y cómo se resolvieron: Los sprites no estaban aún en el proyecto; se copiaron desde el paquete de fase 9 y Godot los importó correctamente. Arranque headless y tests core pasaron.
- Qué tienen que probar los humanos: Recoger doblones, abrir cofres de cada arena, comprobar que los iconos de hechizo coinciden con el objeto ganado y que sus animaciones se distinguen sin solaparse.

Formato de cada entrada:

```
### Fase N — <título> (<fecha>)
- Qué se ha hecho:
- Decisiones:
- Problemas encontrados y cómo se resolvieron:
- Qué tienen que probar los humanos:
```

### Fase 0 — Plan (10/11/2026)
- Qué se ha hecho: Preparado el kit (`AGENTS.md` y `docs/`) en la raíz y revisado `project.godot` junto con el plan y los prompts. Detectada la configuración de Godot 4.7 (`config/features` contiene `4.7`). No se ha escrito código.
- Decisiones: Seguir las fases en orden. Compatibility cumple AGENTS.md; Clásico se resuelve como inventario que puede cambiar al recibir un golpe; cuatro espejos de dos patrones producen ocho obstáculos. Orden: Fase 1 lógica pura; Fase 2 partida local; Fase 3 red; Fase 4 feedback; Fase 5 estética; Fase 6 progresión; Fase 7 accesibilidad; Fase 8 entrega.
- Problemas encontrados y cómo se resolvieron: El directorio de trabajo no contiene `.git`, así que no se pudo hacer el commit solicitado. La discrepancia entre Forward Plus y Compatibility se resolvió usando Compatibility.
- Riesgos y ambigüedades: La autoridad del servidor combinada con movimiento local requiere validación tolerante a latencia y recogidas atómicas; anfitrión debe compartir eventos sin duplicarlos. El lobby y la partida en red siguen pendientes de integración.
- Qué tienen que probar los humanos: Confirmar que el proyecto abre en Godot 4.7 y revisar ambas reglas de juego.

### Fase 1 — Lógica base (10/11/2026)
- Qué se ha hecho: Añadidos `core/game_config.gd`, `arena_gen.gd`, `scoring.gd`, `item_table.gd`, `ranking.gd` y `tests/run_tests.gd`. El generador produce ocho obstáculos en patrones espejo; el objetivo Clásico usa el inventario actual y las probabilidades se renormalizan al excluir el Anillo.
- Decisiones: Los patrones espejo se cuentan como ocho obstáculos. En Clásico los doblones robados cambian el marcador.
- Problemas encontrados y cómo se resolvieron: Al principio no se encontró Godot en PATH; después se localizó Godot 4.7.2 y se ejecutó el runner completo.
- Qué tienen que probar los humanos: Ejecutar `godot --headless --path . --script res://tests/run_tests.gd` en el PC del proyecto y revisar las distancias en pantalla.

### Fase 2 — Partida local (10/11/2026)
- Qué se ha hecho: Añadida escena principal dibujada por código, movimiento, bots, colisiones básicas, monedas, combo, robo con dash, cofres, ruleta, hechizos, corona, cuenta atrás, dos modos y pantalla de resultados con revancha.
- Decisiones: Los bots completan la partida local; el jugador local ocupa la primera ranura.
- Problemas encontrados y cómo se resolvieron: La escena arrancó en Godot 4.7.2 sin errores de parser ni runtime. No se pudo controlar el juego manualmente desde la integración usada.
- Qué tienen que probar los humanos: Jugar ambos modos, comprobar colisiones con obstáculos y recoger monedas soltadas tras un golpe.

### Fase 3 — Red (10/11/2026, parcial)
- Qué se ha hecho: Añadidos autoloads ENet, descubrimiento UDP y endpoint TCP con `/status`, `/results` y `/`.
- Decisiones: Se dejaron las entradas del endpoint en JSON simple.
- Problemas encontrados y cómo se resolvieron: El lobby, la sincronización de posiciones, la simulación autoritativa compartida y la revancha por red no quedaron integrados; el proceso dedicado solo abre transporte/endpoints.
- Qué tienen que probar los humanos: Importar el proyecto, verificar puertos 7777/7778/8080 y terminar la integración de snapshots/eventos antes de presentar multijugador.

### Fase 4 — Feedback (10/11/2026, parcial)
- Qué se ha hecho: Añadidos tonos sintetizados, mensajes flotantes, sonido de recogida, golpes y aviso de Frenesí.
- Decisiones: Se usó síntesis de tonos sin recursos de audio externos.
- Problemas encontrados y cómo se resolvieron: No se implementó el conjunto completo de música, cámara lenta, partículas y secuencias de victoria.
- Qué tienen que probar los humanos: Revisar niveles de sonido y movimiento reducido en el juego.

### Fase 5 — Estética (10/11/2026, parcial)
- Qué se ha hecho: Añadida paleta de cuatro biomas, escenario procedural, personajes de color con símbolos, doblones, cofres y tema de controles.
- Decisiones: El renderizador se cambió a GL Compatibility para cumplir AGENTS.md; se usa la fuente integrada de Godot porque el kit no incluye Lilita One ni Baloo 2.
- Problemas encontrados y cómo se resolvieron: El menú, lobby jugable, ilustración final de personaje y decoración específica por bioma quedaron simplificados.
- Qué tienen que probar los humanos: Revisar visibilidad, escala del HUD y legibilidad a resolución objetivo.

### Fase 6 — Perfil y progresión (10/11/2026, parcial)
- Qué se ha hecho: Añadidos perfil persistente, XP, niveles, personalización básica, historial de partidas y podio de texto.
- Decisiones: Los registros locales viven en `user://matches/` y el perfil en `user://profile.cfg`.
- Problemas encontrados y cómo se resolvieron: No se implementaron desbloqueos por nivel ni animaciones del podio.
- Qué tienen que probar los humanos: Completar partidas, reiniciar el juego y revisar perfil e historial.

### Fase 7 — Accesibilidad (10/11/2026, parcial)
- Qué se ha hecho: Añadidos controles de teclado y mando para movimiento, dash y hechizo; ajustes persistentes para reducir movimiento, escala UI e idioma es/ca/en.
- Decisiones: Se conserva foco de teclado en botones y se usan símbolos además de colores.
- Problemas encontrados y cómo se resolvieron: La cobertura de traducciones y navegación completa por mando no pudo verificarse sin ejecutar Godot.
- Qué tienen que probar los humanos: Probar los menús solo con mando/teclado y las tres opciones de idioma y escala.

### Fase 8 — Entrega (10/11/2026, parcial)
- Qué se ha hecho: Añadidos README, preset de exportación de Windows y paquete `VoodooCombo 0.1`. No se hizo commit por instrucción del usuario.
- Decisiones: Se documenta explícitamente que multijugador y endpoint dedicado no equivalen aún a una partida en red terminada.
- Problemas encontrados y cómo se resolvieron: La exportación oficial no pudo usar las plantillas de Windows que faltan; el paquete de runtime alternativo se generó y se probó en modo headless. La red aún no se probó entre equipos.
- Qué tienen que probar los humanos: Ejecutar el paquete Windows y terminar la conexión de la simulación de red antes de dar la entrega por lista.

### Revisión y build 0.1 (10/11/2026)
- Qué se ha hecho: Corregido el inventario de Clásico para que el dash pueda robar y modificar el marcador; corregidos los bots que quedaban aturdidos permanentemente y la dirección/velocidad de su dash; las reposiciones de cofres/monedas evitan obstáculos y monedas cercanas; BFS ahora exige conectividad completa; los obstáculos miden de 1 a 3 casillas. Configurados nombre y versión 0.1.
- Decisiones: Las plantillas oficiales de exportación Windows no están instaladas. El paquete local usa un lanzador pequeño, el runtime Godot 4.7.2 y el PCK; deben permanecer juntos en `build/`.
- Problemas encontrados y cómo se resolvieron: La exportación Windows oficial falló por ausencia de `windows_debug_x86_64.exe` y `windows_release_x86_64.exe`; se produjo y probó el paquete de runtime alternativo. La suite core y el arranque headless del runtime pasan.
- Qué tienen que probar los humanos: Ejecutar `build/VoodooCombo-0.1.exe` en Windows, confirmar el menú y jugar una partida de cada modo. Para una exportación autocontenida estándar, instalar las plantillas de exportación de Godot 4.7.2 y usar `export_presets.cfg`.

### Revisión — Integración del paquete de personajes y arenas (13/11/2026)
- Qué se ha hecho: Copiados al proyecto los recursos y guías de `VoodooCombo-pack-companero`; `ArenaGen` ahora carga `arenas.json`, elige entre las cuatro arenas sin repetir la anterior, usa sus salidas/obstáculos y coloca doblones evitando trampas fijas. La partida dibuja los fondos, sprites de personajes con animaciones básicas y sprites de trampas periódicas. Actualizados `build/VoodooCombo-0.1.pck` y `build/VoodooCombo-0.1-Windows.zip`.
- Decisiones: Se conservaron los datos y los nombres de archivos originales del paquete. El generador acepta los arrays que trae `arenas.json` y el formato de texto documentado en `ARENAS.md`; la selección de salidas y sus asignaciones usa la semilla.
- Problemas encontrados y cómo se resolvieron: Godot no podía escribir su configuración en las rutas de usuario del entorno; al redirigir `APPDATA`, `LOCALAPPDATA` y las carpetas temporales a `.godot-appdata/` y `.godot-tmp/`, se generó un PCK válido. La suite core pasó y el PCK actualizado arranca en modo headless.
- Qué tienen que probar los humanos: Abrir `build/VoodooCombo-0.1.exe` y confirmar las cuatro arenas, el encaje de los fondos, escala/animación de los personajes, colisiones y ubicación de doblones. Las imágenes de las trampas están integradas; sus efectos de juego aún no están conectados.

### Fase 9f — HUD ilustrado (13/11/2026)
- Qué se ha hecho: Sustituido el marcador de texto por cuatro fichas con panel 9-slice, retrato, nombre, forma, puntuación animada y corona del líder; el reloj ahora muestra minutos y segundos, y la ranura inferior usa los gráficos de hechizos del kit. El HUD se dibuja en una capa superior y conserva el escalado de interfaz.
- Decisiones: Se muestran las cuatro fichas para mantener ubicaciones estables aunque haya menos jugadores; las fichas vacías se ocultan. La ficha local indica «TÚ» según el idioma.
- Problemas encontrados y cómo se resolvieron: Ninguno durante la compilación de scripts y las pruebas headless.
- Qué tienen que probar los humanos: Revisar el HUD en ventana 1280×720 y con escala 100/125/150 %, comprobar corona y puntos durante una partida y verificar los iconos de hechizos.

### Fase 9g — Menú y cierre de partida (13/11/2026)
- Qué se ha hecho: Sustituido el menú provisional por el fondo, logo y botones 9-slice del kit; añadidas entradas escalonadas, sonidos de foco/selección, navegación por personajes Brasa/Colmillo/Tuerca/Cripta con vista idle y guardado en el perfil. El final muestra «¡TIEMPO!» durante un segundo, luego presenta retratos, puntuación y premios sobre fondo limpio; la revancha o el menú principal responden al foco inicial, el resultado vuelve al menú tras 10 s y el cierre desde resultados o pausa limpia el estado de partida. Integradas las fuentes New Rocker, Lilita One y Baloo 2 del repositorio destino, y actualizados PCK y ZIP.
- Decisiones: Se conserva el runtime de consola que usa el lanzador en el ZIP y se omite el ejecutable GUI de 181 MB, que el lanzador no utiliza. El tema asigna New Rocker a botones, Lilita One a títulos y cifras, y Baloo 2 al texto general.
- Problemas encontrados y cómo se resolvieron: El escaneo de Godot sigue avisando de un segundo `project.godot` dentro de `voodoocombo/`; se deja fuera de los commits porque es un proyecto anidado ajeno al checkout activo. La primera comprobación tras integrar las fuentes encontró que Godot no infería como entero la altura del podio; se tipó explícitamente y las comprobaciones posteriores quedaron limpias.
- Qué tienen que probar los humanos: Navegar el menú solo con teclado y solo con mando; elegir cada personaje y reiniciar para verificar el perfil; jugar tres partidas seguidas y comprobar que tras el resultado o al salir de pausa vuelve un menú limpio; probar todas las trampas en las cuatro arenas, el HUD a escalas 100/125/150 % y los bots contra muros/esquinas durante dos minutos.

### Fase 10a — Puntos y reposición (17/11/2026)
- Qué se ha hecho: Combo x1/x2/x3 con umbrales 5 y 12; Frenesí y Anillo añaden un punto cada uno, hasta 5. VoodooCombo empieza con 30 monedas y repone bajo 12 a ritmo de 1/s, hasta 18 en Frenesí; Clásico conserva 50 y no repone. Actualizados la generación y los tests de ambos modos.
- Decisiones: `ArenaGen.generate()` recibe un indicador de modo y un `arena_id` opcional preparado para la selección de mapas del bloque 10f.
- Problemas encontrados y cómo se resolvieron: Ninguno; pasaron los tests core y el smoke test del proyecto.
- Qué tienen que probar los humanos: Confirmar que una partida VoodooCombo termina normalmente entre 60 y 150 puntos, que Clásico sigue empezando con 50 y que el Frenesí no permite superar 5 puntos por doblón.

### Fase 10b — Daño porcentual de trampas (17/11/2026)
- Qué se ha hecho: Las raíces, pinchos, fantasma, vapor, barril y rayo usan el mismo `apply_hit`: quitan 15 % de doblones, con mínimo 2 y máximo 10, sueltan las monedas en abanico con bloqueo de recogida 0,6 s y conservan aturdimiento/empuje. Los golpes de dash entre jugadores mantienen sus porcentajes. Actualizados `AGENTS.md`, `ARENAS.md` y tests de límites.
- Decisiones: El redondeo porcentual sigue usando techo, igual que los golpes de dash; el resultado nunca supera las monedas que lleva el jugador.
- Problemas encontrados y cómo se resolvieron: Ninguno; Godot cargó los scripts y pasó la suite core.
- Qué tienen que probar los humanos: En cada trampa, comprobar pérdidas de 15 % (0, 1, 10, 40 y 200 monedas: 0, 1, 2, 6 y 10), abanico, bloqueo de 0,6 s y diferencias con el dash de otro jugador.

### Fase 10c — Activación de hechizos (17/11/2026)
- Qué se ha hecho: Los cofres guardan el hechizo y E/B activa la ranura. Los efectos temporales empiezan al activarlos; los instantáneos requieren un objetivo. Los bots activan efectos útiles durante sus decisiones. Añadidos el aro de la ranura, el brillo, las teclas E/B y una tarjeta con nombre y descripción traducidos.
- Decisiones: Capa, botas, imán y anillo duran 8/4/5/6 s desde la activación; oveja conserva sus 3 s y los instantáneos se consumen al lanzarse.
- Problemas encontrados y cómo se resolvieron: Ninguno en los tests core; la carga headless del editor y los tests pasan.
- Qué tienen que probar los humanos: Abrir cofres, guardar varios tipos de hechizo, activar con E y B, comprobar duración/caducidad, escudo y resultados contra rivales; verificar que la tarjeta desaparece a los 2 s y que los bots usan hechizos con sentido.

### Fase 10d — Colisión con la huella visible (17/11/2026)
- Qué se ha hecho: El movimiento y los empujes de jugadores usan el campo `hitbox` de los obstáculos y un círculo en los pies de radio 14 px, 12 px bajo el centro. Se mantienen el rectángulo de rejilla/monedas y el radio de 22 px para separación entre jugadores.
- Decisiones: Se deja la geometría de bordes de arena en el radio de jugador y se usa el radio de pies solo frente a objetos.
- Problemas encontrados y cómo se resolvieron: Ninguno; suite core y carga del editor pasan.
- Qué tienen que probar los humanos: Caminar despacio contra troncos y otros obstáculos de las cuatro arenas; comprobar que el sprite llega a la huella visible, que no atraviesa el objeto y que la separación de jugadores sigue funcionando.

### Fase 10e — Alineación de rayo y cintas (17/11/2026)
- Qué se ha hecho: El rayo ahora dibuja sus brazos desde `center + OFFSET`, alineados con el centro usado para el daño. Las cintas voltean el sprite cuando `dir.x` es negativo y dibujan rodillos en los extremos; el empuje ya usa la dirección `dir` del JSON. Revisada la referencia visual de las cuatro arenas.
- Decisiones: No cambié las posiciones del JSON porque coinciden con la imagen de referencia.
- Problemas encontrados y cómo se resolvieron: Ninguno; carga headless del editor y suite core pasan.
- Qué tienen que probar los humanos: Confirmar que el daño del rayo coincide con el haz visible en Biblioteca y que ambas cintas del Taller muestran flechas y rodillos en la dirección del empuje.

### Fase 10f — Elección de arena (17/11/2026)
- Qué se ha hecho: Tras seleccionar VoodooCombo o Clásico se muestran cuatro tarjetas con miniatura, nombre traducido e iconos de trampas, además de ALEATORIA. Ratón, foco de teclado/mando y Esc funcionan. Se guarda la selección preferida y la última arena en el perfil; `ArenaGen` aplica la seleccionada o elige aleatoriamente evitando la anterior.
- Decisiones: La opción aleatoria se conserva como preferencia, y la última arena concreta se guarda por separado para no repetirla.
- Problemas encontrados y cómo se resolvieron: Ninguno; se copiaron las miniaturas e iconos del kit y pasan tests de selección explícita y aleatoria.
- Qué tienen que probar los humanos: Elegir las cuatro tarjetas y aleatoria en ambos modos, volver con Esc, verificar los iconos, y reiniciar para confirmar que recuerda la preferencia y que aleatoria no repite el mapa anterior.

### Fase 10g — Pantalla de carga (17/11/2026)
- Qué se ha hecho: Entre la elección y la cuenta atrás se muestran durante 15 s el nombre y la miniatura de la arena, sus trampas con icono y efecto, los controles, el personaje/nombre/J1, un consejo que cambia cada 4 s y una barra de progreso. En práctica aparece Espacio para saltar desde el segundo 5.
- Decisiones: La partida y las monedas se preparan antes de abrir la carga; saltar solo evita la espera y siempre conserva la cuenta atrás 3-2-1.
- Problemas encontrados y cómo se resolvieron: Ninguno; el manifiesto `carga.json`, carga headless del editor, tests core y smoke test pasan.
- Qué tienen que probar los humanos: Comprobar la carga de 15 s, el cambio de consejos, iconos/textos según cada arena y el salto con Espacio a partir de 5 s; verificarlo en ambos modos.

### Fase 10h — Nombre e identidad del jugador (17/11/2026)
- Qué se ha hecho: En un perfil sin nick aparece el diálogo inicial; valida 3–12 caracteres y recorta espacios externos. PERSONAJES permite cambiarlo. En partida cada muñeco lleva su nick contorneado; el local añade «TÚ», su color, una flecha y un aro bajo los pies. Los bots conservan sus nombres propios.
- Decisiones: La validación vive en `NicknameRules` para poder probarla como lógica pura. El nick se guarda en el mismo `Profile` que se usa para el marcador.
- Problemas encontrados y cómo se resolvieron: La primera versión del test intentó acceder al autoload `Profile` desde el test `SceneTree` y no compiló; se extrajo la regla a `NicknameRules` y los tests core pasan.
- Qué tienen que probar los humanos: Crear un perfil nuevo, probar nombres de 2, 3 y 13 caracteres y espacios externos; cambiar el nick desde PERSONAJES y comprobar sobre la arena colores, contornos, flecha, aro y nombres de bots.

### Fase 10i — Textos flotantes legibles (17/11/2026)
- Qué se ha hecho: Los doblones usan Lilita One de 30/36 px con contorno de 6 px; avisos de combo y trampas usan New Rocker de 44/64 px con contorno de 8 px. Duran 1,2/1,6 s, suben 40 px y se desvanecen al final. Los avisos de combo aparecen centrados arriba y el jugador local muestra multiplicador y racha en un círculo.
- Decisiones: El color de «+N» sigue el nivel de combo (blanco, naranja, rosa); reducir movimiento elimina el ascenso y el pop.
- Problemas encontrados y cómo se resolvieron: Ninguno; suite core, smoke y carga headless pasan.
- Qué tienen que probar los humanos: Recoger doblones con multiplicadores x1/x2/x3, confirmar tamaños/colores/contorno/duración, y activar avisos de trampa y combos con «Reducir movimiento» encendido y apagado.

### Fase 10j — Cierre de la zona segura (17/11/2026)
- Qué se ha hecho: La zona se encoge según el reloj de cada modo y termina en 18×9 casillas. Tres segundos antes se anuncia con borde morado y sonido. Fuera, los jugadores van al 70 % y pierden un doblón cada 0,75 s; monedas y cofres exteriores se reubican dentro con fundido. Los bots que quedan fuera buscan volver al centro. La niebla usa la textura del kit y se detiene con Reducir movimiento.
- Decisiones: Las reapariciones nuevas de cofres y monedas también usan la zona actual. Se usa `ZoneRules` para la geometría y el temporizador de pérdida.
- Problemas encontrados y cómo se resolvieron: La primera prueba de escena reveló un `return` no válido dentro del fragment shader; se cambió por una rama `if/else`. La escena real pudo crear el HUD y aplicar el tercer paso sin error de shader.
- Qué tienen que probar los humanos: Probar los tres avisos y encogimientos en ambos modos, medir 18×9 al final, dejar un jugador fuera 3 s (4 doblones menos), y comprobar reubicación de cofres/monedas, movimiento de niebla y bots que regresan.

### Fase 10k — Ventana ajustable (17/11/2026)
- Qué se ha hecho: El lienzo continúa en 1280×720; la ventana abre a 1920×1080, se puede redimensionar y usa `canvas_items` con aspecto `keep`. AJUSTES permite ventana/pantalla completa y los tres tamaños previstos. F11 alterna pantalla completa; se guardan ambas opciones.
- Decisiones: Al cambiar resolución en pantalla completa se actualiza la preferencia guardada; se aplica al volver a modo ventana.
- Problemas encontrados y cómo se resolvieron: Ninguno; carga del editor, tests core y arranque headless pasan.
- Qué tienen que probar los humanos: Abrir a 1920×1080, redimensionar, probar los tres tamaños, alternar pantalla completa desde AJUSTES y F11 y reiniciar para comprobar persistencia y proporciones.

### Fase 10l — Podio, emotes y taquilla (17/11/2026)
- Qué se ha hecho: Se rediseñaron los resultados con el fondo y podio del kit, personajes animados que entran en orden, corona y placas de nombre/puntuación. Se añadieron emotes temporales con teclas 1–4 y cruceta, una barra visual y reacciones aleatorias de bots. La taquilla agrupa personaje, marcos, estelas y emotes equipables; los desbloqueos se derivan del nivel, se guardan las selecciones y los marcos aparecen en el HUD. La XP sigue persistiendo, pero ya no se muestra en menú ni resultados; el retorno automático es a los 15 s.
- Decisiones: El nivel empieza en 1; los desbloqueos múltiples de una partida se condensan en una tarjeta con el primer objeto de la lista. El marco de calavera usa el marco de hueso del kit con un símbolo de calavera superpuesto porque el kit no incluye un PNG separado. Los umbrales, espera, tamaños y tiempos de emote están en `GameConfig`.
- Problemas encontrados y cómo se resolvieron: La primera sonda de resultados encontró un tween de respiración del logo que seguía activo al cerrar la escena; ahora se detiene al limpiar la interfaz. La sonda de podio y emote pasó después del cambio. La carga del editor y la suite core también pasan; el editor aún avisa de la carpeta de proyecto anidada `voodoocombo/` y el arranque headless termina con el aviso previo de instancias ObjectDB.
- Qué tienen que probar los humanos: Completar una partida y comprobar orden/animación del podio, monedas y puntuaciones, corona, 15 s sin entrada, volver a activar el temporizador con una tecla y usar ¡Otra!. Probar emotes 1–4 y cruceta, duración de 2 s, enfriamiento de 1 s y emotes de bots. En TAQUILLA, equipar personaje/marco/estela y exactamente cuatro emotes; comprobar marcos bloqueados, niveles, desbloqueos, marco en HUD y estelas al hacer dash. Confirmar que XP no aparece en menú/resultados y se conserva al reiniciar.

### Fase 11a — Letra y color Brasa minimal (documentos revisados)
- Qué se ha hecho: Incorporados desde fases-11-12.zip los dos planes y sus versiones de AGENTS. Activada la versión de fase 11. Tema Cinzel/Oswald con reserva de fuente, espaciado de títulos/botones, logo Brasa, botones de texto con foco visible, punto, línea y brasas. Textos flotantes con tweens en Fx: rebote, giro, caída/temblor de pérdidas, carteles con línea y pulsos; marcador que cuenta y distingue las pérdidas. Retiradas las fuentes antiguas del proyecto activo.
- Decisiones: Se sigue el orden del ZIP: tipografía es 11a y extracción de MatchSim es 11b. La fase 12 conserva su AGENTS dentro de docs hasta que llegue su turno.
- Problemas encontrados: La primera edición del tema se dividió en dos operaciones por una limitación del editor de parches. La carga posterior del editor y las pruebas core pasan. Persiste el aviso previo de un proyecto anidado y ObjectDB al salir en headless.
- Qué deben probar los humanos: Menú con ratón, teclado y mando; textos de ganancia/pérdida, carteles y marcador a escalas 100/125/150%; repetir con Reducir movimiento. La revisión headless no certifica el acabado visual.

### Fase 11b — Simulación compartida y vista local
- Qué se ha hecho: Sustituido el prototipo incompleto de MatchSim por la extracción de las reglas que ejecutaba main.gd: movimiento y bots, cofres, ruleta, hechizos, golpes, trampas, reposición, combo, reloj, zona y resultado. MatchSim es RefCounted, recibe inputs y genera snapshots y eventos; main consume esos datos a 30 Hz y conserva UI, entrada, audio, efectos y persistencia. La simulación no utiliza nodos, Input, Settings, Fx, Sfx ni otros autoloads.
- Decisiones: Se conserva el comportamiento previo al separar responsabilidades. Los textos de eventos contienen claves que traduce la vista. El snapshot hace copia profunda para impedir que la vista cambie la simulación. La carga y cuenta atrás siguen siendo estados de presentación previos al primer tick.
- Problemas encontrados: Python del PATH era un acceso de WindowsApps no ejecutable; se realizó la extracción con las herramientas de edición disponibles. La prueba de integración muestra el aviso de ObjectDB al cerrar; no aparecen errores de ejecución en la partida.
- Verificación: Dos simulaciones de 90 s con cuatro bots por arena comparan estado y eventos. Test de escena local comprueba que la vista avanza MatchSim y que modificar un snapshot no modifica el modelo.
- Qué deben probar los humanos: Una partida de VoodooCombo y Clásico en cada arena; cofres y siete hechizos, trampas, combos, zona, pausa, podio y revancha. Comparar la sensación con la fase 10 antes de probar la red.

### Fase 11c — Arranque dedicado
- Boot decide entre vista y servidor antes de cargar las texturas; Sfx no crea audio en el servidor. Net conserva todas las RPC y la conexión ENet (32 peers); server_main dispone del reloj de 30 Hz para las salas.
- API contrastada con la documentación oficial Godot 4.7 de ENet y multijugador de alto nivel. Logs fechados de conexión y desconexión.
- Verificación: importación headless y servidor UDP 17777 con dos procesos cliente de tests/test_network_client.gd; ambos completan ping/pong y salen correctamente.
- Humanos: arrancar con --headless -- --server --port 7777 y comprobar conexiones desde el segundo PC. Las salas se implementan en 11d.

### Fase 11d — Salas con código
- RoomDirectory gestiona códigos únicos, ocho salas, aforo de cuatro, migración del anfitrión, bloqueo al empezar, caducidad vacía y cinco intentos/minuto. Net usa siempre el remitente real de ENet.
- Tests: test_rooms.gd comprueba aforo, versión, códigos inexistentes, límite, migración y caducidad. Importación headless sin errores.
- La prueba ENet de 11c necesitó ejecutar servidor y clientes juntos fuera del aislamiento de red; dos rondas ping/pong verificadas. La prueba completa con cuatro clientes queda integrada con 11g.
- Humanos: comprobar los mensajes de error y copiar el código en el lobby que incorpora 11e.

### Fase 11e — Lobby de mazmorra y rueda social
- Añadidos entrada online, crear/unirse, práctica con tres bots, estrados con jugador local en segundo lugar, anfitrión, listo, bots, modos y copia de código. Fondo del pack con antorchas, polvo, niebla y araña; animación desactivable.
- Rueda de ocho ranuras en Q/Y, accesos 1–4, cuatro bailes, dieciséis emotes y seis gritos propios. La taquilla permite asignar ranuras según nivel; el servidor limita mensajes sociales a uno por segundo.
- I18n es/ca/en para la UI nueva. Test de lobby: cuatro personajes, segundo estrado y ocho botones; pasó. El primer test usó carga anticipada incompatible con autoloads bajo --script; corregido con carga diferida. Persisten dos avisos ObjectDB al salir del test.
- Humanos: comprobar composición, foco con mando, rueda mantenida, gritos y bailes entre clientes. El paso de listo a votación se conecta en 11f.

### Fase 11f — Votación compartida
- ArenaVote cuenta votos durante diez segundos, permite cambiarlos, programa votos de bots y genera una secuencia horaria reproducible para empates o ausencia de votos. El último salto coincide con el ganador.
- Vista de cuatro cuadrantes con assets y posiciones del JSON, premisas traducidas, retratos, marco iluminado y crecimiento del ganador. El servidor publica la misma votación; práctica usa la misma clase y conserva semilla y roster hasta MatchSim.
- Tests test_vote.gd y test_lobby_view.gd: empate 2–2, nadie vota, voto inválido, determinismo y recorrido lobby→votación→carga; pasan.
- Humanos: comparar ruleta en cuatro pantallas y comprobar navegación de cuadrantes con mando. Las conexiones de carga a partida se completan en 11g.

### Fase 11g — Partida autoritativa en red
- Entradas 30 Hz con secuencia, movimiento finito limitado a uno, caducidad de entrada y deduplicación de dash/hechizo fiable. Simulación servidor 30 Hz y snapshots 20 Hz; compresión y fragmentos de 1000 bytes evitan exceder la MTU. Se reenvía el estado de doblones para recuperarse de pérdidas.
- ClientMatch predice movimiento con ArenaPhysics, aplica umbrales 8/64 px e interpola rivales con 100 ms. Vista identifica al jugador real, muestra ping y usa eventos y resultado del servidor.
- Test tools/test-network.ps1 con servidor y cinco procesos: cuatro entran, votan 2–2, comparten baile, envían movimiento de longitud 5 y reciben idéntico ranking; quinto rechazado. Sin errores en los logs. Test de vista online y regresión local también pasan.
- Problemas corregidos durante la prueba: colisión con Node._input, paquete mayor que MTU y avisos ENet por relay al desconectar simultáneamente; relay desactivado, pues todos hablan con el servidor.
- Humanos: jugar con latencia y pérdida reales, comprobar correcciones de posición, dash y hechizos. La prueba automatizada usa una partida de tres segundos; la simulación de noventa segundos está cubierta por los tests core.

### Fase 11h — Desconexiones, resultados y revancha
- Una desconexión elimina al muñeco de movimiento, colisiones, trampas y clasificación. Con dos humanos continúa; el último humano gana aunque el jugador que se marchó tuviera más puntos. Evento visual de salida y mensaje al perder el servidor.
- El servidor guarda JSON por sala, publica resultados y estado HTTP. Revancha devuelve a la misma sala con todos no listos; podio online conserva la sala y comparte emotes.
- Corregida una sangría en los bucles de hechizos durante la integración. Tests de desconexión, vista local y vista online pasan; prueba real de cuatro clientes más quinto rechazado también pasa con el mismo ranking y sin errores de red. El test de vista sigue mostrando dos instancias ObjectDB al terminar.
- Humanos: comprobar abandono durante carga, partida y podio; pulsar Otra en dos clientes; verificar /results y cierre del servidor durante una partida.

### Fase 11i — Preparación del despliegue
- Presets Windows, Linux ARM64 y x86_64 dedicados; scripts de arranque, servicio systemd y guía Oracle/LAN. Ajustes de servidor editables y persistentes, sin inventar una IP Oracle.
- Documentación oficial de Godot 4.7 y Always Free consultada. El despliegue externo corresponde a los humanos; no se han creado recursos. No hay plantillas de exportación instaladas en las rutas comprobadas; los presets quedan preparados y la exportación binaria pendiente de disponer de ellas.
- Test de vista online pasa. Humanos: instalar plantillas coincidentes, exportar, probar en Linux y desde dos redes; seguir docs/DESPLIEGUE.md y verificar cuota gratuita.

### Fase 11j — Validación y límites
- RPC con lista cerrada, esquema de tipos, límite de tamaño/frecuencia, movimientos finitos y cosméticos existentes y desbloqueados según XP calculada por el servidor. El perfil local no autoriza cosméticos online: sin cuentas autenticadas, la progresión online se conserva durante la conexión; no se confía en una XP enviada por el cliente.
- Test de esquemas y cosméticos pasa; prueba ENet de cinco procesos pasa sin errores. Se mantienen remitentes reales y autoridad de servidor en todos los eventos.
- Humanos: probar nombres de control, versión diferente, cosméticos bloqueados y spam desde un cliente de desarrollo; verificar que otros jugadores continúan.

### Fase 12a — Golpes y recogida
- Actualizadas instrucciones a fase 12. Fx gestiona parón visual proporcional, chispas, aplastamiento y vibración; la simulación no se detiene. Sacudida amortiguada y zoom corto en golpes fuertes. Ajustes persistentes de destellos y mando.
- Regresión local pasa. Humanos: comprobar intensidad con mando y reducir movimiento/destellos; verificar que el servidor no ralentiza durante golpes.

### Fase 12b — Doblones al marcador
- Arcos de recogida y robo hacia las fichas con tic al llegar; tono de recogida por semitonos, limitado a doce pasos. Reducir movimiento sustituye los vuelos por una señal breve en destino.
- Humanos: comprobar vuelos simultáneos, correspondencia de fichas en clientes distintos y conteo animado del marcador.

### Fase 12c — Medidor de combo
- Anillo de tiempo, aura x3 y destellos regulables. Pérdida autoritativa de combo con fragmentos y aviso del combo conseguido.
- Corregido un tipo no inferible en el ángulo de partículas. Regresión local pasa; humanos: verificar duración de 1,5 s y accesibilidad.

### Fase 12d — Medallas autoritativas
- Detector puro de medallas, eventos fiables, insignias junto al marcador, recuento de perfil y marcas en podio. Las condiciones se calculan en MatchSim; eventos de cada tick se procesan una sola vez.
- Test de primera sangre, robo maestro, venganza, intocable y dos picos x3 pasa. Humanos: provocar cada medalla y comparar en red, especialmente rozar un dash y remontar.

### Fase 12e — Música por capas
- Tres bucles sintetizados (tambor/bajo, percusión, melodía), mezcla gradual de medio segundo por combo, aceleración y tono de Frenesí, tambor final y silencio antes de fanfarria. Regresión local pasa.
- Humanos: escuchar bucles y transiciones sin cortes y verificar volumen de música independiente de efectos.

### Fase 12f — Tensión y final
- Latido y cuenta atrás central al final, suavizado visual en finales ajustados, confeti y zoom del ganador con pausa previa al podio. La simulación registra quién iba último a mitad para anunciar remontada.
- Humanos: empate cercano en los últimos cinco segundos y remontada desde último; comprobar que los relojes de red siguen sincronizados.

### Fase 12g — Progreso y retos
- Tres retos por semilla, completados en servidor, con bonus de XP sin duplicados. Avisos, pantalla de carga y barra animada de XP con nivel y sonido; desbloqueos sociales y botón Equipar. Tests de selección, condiciones y XP pasan; regresión local pasa.
- Humanos: cumplir tres retos, subir nivel y equipar el desbloqueo; comparar bonus entre clientes.

### Fase 12h — Menús
- Botones con sonido, escala al enfocar y aplastamiento al pulsar; alfiler dibujado, telón de tela al cambiar de pantalla y latido del logo cada cuatro segundos. Reducir movimiento deja los controles estáticos.
- Regresión local pasa. Humanos: recorrer menús con ratón, teclado y mando y comprobar legibilidad de transiciones.

### Fase 12i — Retirada de Clásico
- Retirados selector, constantes, ramas de puntuación, generación y objetos, textos y tests específicos del modo Clásico. La entrada principal usa siempre lobby y votación.
- Humanos: comprobar que no queda opción Clásico y que el modo VoodooCombo conserva sus reglas.

### Fase 12j — Último en Pie
- Tres costuras, fantasma sin colisión ni acciones, daño común, Costura Extra, zona de cinco pasos y muerte súbita, rondas con nueva arena y victoria al ganar dos. Bots persiguen rivales y huyen con una costura; vista recibe rondas por eventos fiables.
- Test de tres impactos, cambio de arena, dos rondas ganadas y zona mínima pasa. Corregida llamada antigua del test local tras retirar Clásico y ubicación de predicción de fantasmas; regresión local pasa.
- Humanos: partida completa en las cuatro arenas, empates a tiempo, espectador fantasma y cambio de arena en red.

### Fase 12k — Codicia 2v2
- Equipos de dos, cuarenta doblones, valor sin multiplicador, carga que frena/agranda, depósito progresivo protegido, caída de toda la carga y bloqueo de daño aliado. Bots regresan al cofre y protegen al compañero; hechizos eligen rivales.
- Tests de cofre correcto, banco protegido, daño aliado y velocidad x0,6 pasan; regresión local pasa. Humanos: equipo contra equipo en red, comprobar anillo/Frenesí y robar antes de depositar.

### Fase 12l — Selección y explicación de modos
- Selector de tres modos y duración, tarjetas de reglas traducidas, equipos visibles/cambiables por anfitrión, instrucciones en carga y objetivo al empezar ronda. Los huecos de Codicia se completan con bots.
- Pruebas de lobby y vista online pasan. Humanos: recorrer los tres modos, cambiar equipos y jugar una partida local y otra en red por modo; comprobar desconexión entre rondas.

### Revisión final de fase 12 — interfaz, regresión y paquete
- Corregidos los tamaños de las texturas de menú, votación, HUD y podio; se limpian vuelos y textos al cambiar de partida. El marcador del podio ahora muestra monedas y medallas, y la pantalla de resultados enseña el nivel y el progreso de XP.
- Último en Pie usa las costuras del asset en las fichas. Codicia pinta los retratos y marcadores de cada equipo con su color y separa los dos totales. Los bots usan nombres propios. Ajustes incluye deslizadores persistentes para música y efectos.
- Votación cubre el lobby, recorta las cuatro cartas y enseña medallón, trampas y retratos de voto. El historial muestra el total de medallas del perfil.
- Godot 4.7: `tests/run_tests.gd` pasa sin avisos de instancias filtradas; `test_full_modes.gd` completa VoodooCombo, tres rondas de Último en Pie y Codicia. La prueba ENet con cuatro clientes y un quinto rechazado pasa en los tres modos; los cuatro clientes coinciden en el resultado y `/results` indica el modo correcto. Capturas gráficas de menú, ajustes, lobby, votación, los tres modos y podio sin errores.
- Primer intento de la prueba ENet desde el aislamiento local agotó el tiempo al no poder conectar los procesos; repetida con permiso para sockets locales pasa en los tres modos.
- Humanos: abrir el paquete Windows 0.1; probar ajustes de audio, resolución y controles; perder costuras hasta ser fantasma; jugar Codicia con dos equipos y confirmar color, carga, cofre y marcador; revisar retratos de voto y medallas del podio; probar Otra y Menú principal en dos clientes.

### Revisión de cierre — fase 12
- Auditoría de 12a–12l contra `docs/codex/fase-12/FASE-12.md`. Corregido el arranque de Sfx en modo headless para no crear reproductores de audio en las pruebas; Godot ya no informa instancias de audio retenidas al salir. Añadidos los UID de tests y los metadatos de importación que el escaneo limpio de Godot genera.
- Repetidos los tests de lógica, retos, desconexión, modos completos, lobby, partida local, medallas, reglas de sala/RPC, supervivencia, equipos, votación y vuelta ENet. `tools/test-network.ps1` pasa en los tres modos: cuatro clientes coinciden, el quinto se rechaza y `/results` refleja el modo. El paquete Windows actualizado se extrae y arranca con su lanzador.
- Pendiente de prueba humana: comprobar la ventana y mandos en Windows, revisar el feedback visual/sonoro con los ajustes de accesibilidad y jugar los tres modos con personas en redes distintas. El despliegue de Oracle y la exportación Linux dedicada requieren las plantillas oficiales de Godot y configuración humana; no se ha creado ninguna VM.

### Fase 13j — cierre y entrega
- Actualizado AGENTS.md con selector de modos, carga/podio, codec de snapshots y el objetivo de tamaño. Capturas gráficas 1920×1080 guardadas para menú, selector de modo, carga de Codicia y podio; inspección visual del selector confirma jerarquía, foco y textos legibles. Las capturas previas de taquilla y ajustes siguen en esta carpeta.
- Godot 4.7.2: suite core y pruebas dirigidas de retos, vista cliente/local, desconexión, modos completos, lobby, medallas, salas, RPC, snapshots (máx. 1.526 B comprimidos), supervivencia, equipos y votación pasan. Host local, ping y prueba ENet de 4 jugadores más rechazo del quinto pasan; VoodooCombo, Último en Pie y Codicia sincronizan el resultado.
- Instaladas las plantillas oficiales Windows x86_64 de Godot 4.7.2. Reexportado build/VoodooCombo.exe (0.13.0) y recreado build/VoodooCombo-v0.13.0-Windows.zip (53.6 MB); ejecutable y paquete quedan fuera de Git. No se publicó un release de GitHub.
- Humanos: probar filas de ajustes con ratón/teclado/mando al 75 % y 150 %; alojar/unirse desde dos PCs; recorrer las cuatro pestañas de taquilla; partida con cuatro bots y máximo tres textos; lanzar los siete hechizos; acceder a los tres modos; revisar carga y podio con 2, 3 y 4 jugadores.

### Fase 14c — Conexión por invitación y LAN
- La pantalla online ahora muestra crear partida y unirse en columnas. Añadidos códigos `SALA-DIRECCIÓN[:puerto]` con IPv4 base32, orden de adaptadores VPN/LAN que descarta Hyper-V/VirtualBox/VMware/WSL, invitaciones copiables, pegado de portapapeles, selección de red, salas LAN y entrada por solo código mediante consulta broadcast. Si hay UPnP, el mapeo UDP se consulta en segundo plano y se elimina al salir; al fallar, se ofrece ayuda dentro del juego. La IP manual permanece en AJUSTES → ONLINE. El servidor anuncia las salas, versiones, anfitrión, modo y capacidad. Añadidos aviso previo del firewall y botón Oracle condicional.
- `tests/run_tests.gd`, `tests/online_lobby_test.tscn` y arranque headless de Godot 4.7.2 pasan. La ida y vuelta cubre LAN, VPN y puerto personalizado; el test de UI comprueba la lista e invitación. La revisión de captura con renderer headless no es posible porque ese renderer no crea textura de ventana; queda captura visual para verificación humana.
- Humanos: en dos PCs de la misma Wi-Fi comprobar lista y entrada con un clic; repetir con los cinco caracteres y con una invitación completa; verificar adaptador elegido, ventana de firewall, funcionamiento y limpieza UPnP, y mensajes de versión/conexión.
