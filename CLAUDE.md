# CLAUDE.md: contexto para Claude

> Para el Claude que abra este proyecto por primera vez (por ejemplo, desde la cuenta de Joel).
> Resume lo que se ha decidido en las conversaciones con Miquel, que no están en este repositorio.
> **Las reglas del juego y del código están en `AGENTS.md`.** Este archivo no las repite: explica el contexto, cómo se trabaja y qué falta.

## 1. Qué es esto

- **Proyecto:** VoodooCombo, del DevChallenge3 de Proyecto (2º DAM, Institut Baix Camp).
- **Equipo:** Miquel Larios y Joel Puyo.
- **Juego:** party game multijugador hipercasual, de 2 a 4 jugadores. Muñecos vudú recogen doblones en arenas con trampas durante 90 s, encadenan combos y se roban con el dash.
- **Motor:** Godot 4.7 con GDScript y renderer Compatibility.
- **Repositorio:** https://github.com/miquellarios/voodoocombo, rama `main`.

## 2. Cómo se reparte el trabajo

| Quién | Qué hace |
|---|---|
| **Codex** (lo maneja Joel) | Escribe el código del juego en Godot. Lee `AGENTS.md` y hace una fase cada vez, con un commit por bloque (`Fase 11a: …`). |
| **Claude** | Diseño, arte y documentos. Escribe los documentos para Codex (`docs/codex/fase-N-*.md`), genera todo el arte por código, revisa el código de Codex y detecta bugs para la fase siguiente. |
| **Miquel y Joel** | Prueban, deciden y aprueban. |

**Claude normalmente no programa el juego.** Si hay que cambiarlo, escribe o amplía un bloque en `docs/codex/`, salvo que el equipo pida lo contrario.

## 3. Estado actual (24/11/2026)

| Fase | Estado |
|---|---|
| 1-12 | Hechas por Codex. Registro en `docs/BITACORA.md`. |
| **13** | Escrita, pendiente: `docs/codex/fase-13/FASE-13.md` y su `AGENTS.md`. Arregla lo que falló al probar la 12 (ajustes, taquilla, demasiado texto, hechizos sin efecto, modos escondidos, carga y podio) y prepara el ejecutable para probar online alojando desde el juego. |

Capturas de cómo quedó la fase 12: `docs/capturas/fase-12/`.

Cada fase de la 11 en adelante tiene su carpeta con dos archivos:
- `FASE-N.md`: los bloques para Codex;
- `AGENTS.md`: cómo queda el juego al terminar esa fase.

Al empezar una fase, Codex copia ese `AGENTS.md` a la raíz. El de la raíz ahora es el de la fase 12.

Lo que falló al probar la fase 9 (todo está en la fase 10):
- los hechizos se lanzaban solos, sin pulsar E;
- los bonus se multiplicaban, y con un solo doblón se podían llegar a sumar cientos;
- los obstáculos ocupaban el doble de espacio del que se ve;
- el rayo salía desplazado;
- la cinta transportadora estaba girada;
- los textos que saltan duraban muy poco y se veían borrosos.

Qué trae cada fase:
- **Fase 11:**
  - letra nueva;
  - servidor dedicado con ENet;
  - salas con código de 5 letras;
  - lobby de mazmorra con emotes, bailes y gritos de guerra;
  - votación de arena con 4 mapas en las esquinas y ruleta si hay empate.
- **Fase 12:**
  - *game feel*, medallas, música por capas y progreso;
  - quitar el modo Clásico y añadir Último en Pie y Codicia 2v2.

`docs/codex/plan-multijugador.md` es el plan de red que escribió el equipo. Es la base de la parte 1.


## 4. Decisiones del equipo que no hay que volver a plantear

**Puntos**
- Los bonus de un doblón se suman, con un máximo de 5 por doblón.
- Combo x2 a partir de 5 y x3 ("¡VOODOO COMBO!") a partir de 12.
- Cada partida empieza con 30 doblones en la arena.

**Trampas, partida y hechizos**
- Las trampas quitan un 15 % de los doblones (mínimo 2, máximo 10).
- Partidas de 90 s, de 2 a 4 jugadores.
- La zona se encoge a los 45, 35 y 25 s para que nadie se quede esperando en un sitio.
- Hay un solo hueco de hechizo, y el hechizo solo se lanza con la tecla E.

**Pantallas**
- Pantalla de carga de 15 s con consejos, que hace de tutorial.
- Nombre de jugador visible sobre su muñeco.
- Al final, un podio con los personajes celebrando y emotes, en lugar de tablas de texto.
- Los niveles desbloquean cosméticos.

**Modo Clásico**
- Se quita del todo. Miquel lo decidió sabiendo que era el requisito literal del enunciado.

**Modos**
- Los modos nuevos son Último en Pie y Codicia 2v2.
- Quedan como ideas para más adelante, sin hacer: Patata Vudú, Altar, Cazador 1v3 y Fútbol Vudú.

**Online**
- Solo se entra con código de sala.
- Servidor en Oracle Always Free, con un PC del aula en LAN como reserva.
- **No se activa ningún servicio de pago.**

**Lobby**
- Mazmorra oscura con telarañas, en el espíritu de WoW, El Señor de los Anillos, D&D y Magic.
- **Todo original:** ni nombres, ni frases, ni logos de esas marcas.

**Dopamina "de la buena"**
- Nada de cajas de botín de pago ni de rachas diarias.

**Letra y color ("Brasa minimal", ver `AGENTS.md` §7)**
- Títulos y menú: Cinzel Bold, con las letras separadas, en hueso `#EFE7DA`. Lo destacado, en brasa `#FF6A2B` con un brillo suave.
- Textos en partida: Oswald Bold plana con contorno oscuro.
- Sin dorado ni marrón en la interfaz.
- Miquel rechazó varias propuestas antes:
  - las letras góticas;
  - el metal biselado, que le pareció de plástico;
  - los colores demasiado marrones y dorados.
- Lo que quiere es minimalista, y que la dopamina venga del movimiento: rebotes, temblores y números que suben.

Las propuestas descartadas y por qué están en `docs/HISTORIA-IA.md` y en `docs/propuestas/`.

## 5. Arte: cómo se genera

Todo el arte es original y sale de los scripts de Python y Cairo de `tools/arte/`. No hay imágenes de terceros.

**Preparar el PC (una vez)**

```bash
cd tools/arte
pip install -r requirements.txt        # en Linux con el Python del sistema: añadir --break-system-packages
python3 instalar_fuentes.py            # copia las fuentes de assets/fonts a ~/.fonts para Cairo
```

**Convenciones**
- Los assets se exportan al doble de tamaño y en Godot se dibujan a escala 0,5.
- Cada carpeta de assets tiene un `.md` que explica cómo usarla en Godot: `assets/ui/UI.md`, `assets/arenas/ARENAS.md`, `assets/items/ITEMS.md` y `assets/characters/SPRITES.md`.

**Qué script genera cada cosa**

| Script | Qué genera |
|---|---|
| `sprites3.py` | Personajes |
| `export_arenas.py` | Arenas, trampas y `arenas.json`, con la hitbox de cada obstáculo |
| `export_ui.py` | Interfaz de la fase 9 |
| `export_fase10.py` y `export_carga.py` | Fase 10 |
| `export_fase11.py` y `export_fase11b.py` | Lobby y cartas |
| `export_fase12.py` | Votación y medallas |
| `export_tipografia.py` | Logo "Brasa minimal" y referencias de letra |
| `export_fase13.py` | Efectos de hechizos y referencias de hechizos y ajustes |
| `trailer.py` | Tráiler, que necesita `ffmpeg` |

**Cómo se trabaja el arte**
1. Generar en `out/`, que git ignora.
2. Enseñar una vista previa al equipo.
3. Cuando lo aprueben, copiar a `assets/` y las referencias a `docs/media/`.

**Capturas del juego en Godot sin pantalla**

Para revisar pantallas concretas, Claude usa una escena `capture.tscn` (fuera del repositorio). Instancia `main.tscn`, llama a `_build_settings()`, `_begin_match()`, etc., y guarda el viewport con `get_viewport().get_texture().get_image().save_png()`. Se lanza con `--fixed-fps 30 --resolution 1280x720`.


```bash
xvfb-run godot --path . --write-movie /ruta/absoluta/captura.png --fixed-fps 10 --quit-after N
```

La ruta tiene que ser absoluta: con una relativa no se guarda nada.

## 6. Cómo trabajar con Miquel y Joel

- Escriben en castellano informal y rápido. Responde en castellano, claro y sin rollo.
- En lo visual, enseña imágenes antes de cerrar nada. Ofrece varias opciones y deja que elijan; iteran mucho.
- Si algo va contra el enunciado o puede salir mal, avisa una vez y luego respeta lo que decidan.
- **Git:**
  - Haz commits pequeños y descriptivos, en castellano.
  - Antes de hacer push, comprueba que `origin` apunta a `https://github.com/miquellarios/voodoocombo`. A veces vuelve a apuntar al repositorio viejo de Joel, `joelpuyo-source/voodoo-combo`, y ese push falla.
