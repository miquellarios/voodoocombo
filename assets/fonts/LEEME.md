# Fuentes

Fuentes de Google Fonts con licencia **SIL Open Font License 1.1** (ver los `OFL-*.txt`). Son los archivos originales
del paquete `@fontsource`, sin modificar, con el juego de caracteres latino (incluye á, é, ñ, ç, ¡, ¿ y l·l).

Estilo **"Brasa minimal"** (ver `AGENTS.md` §7):

| Archivo | Uso en el juego |
|---|---|
| `Cinzel-Bold.woff2` | Logo, títulos, botones del menú y carteles ("¡VOODOO COMBO!") |
| `Cinzel-Regular.woff2` | Subtítulos finos |
| `Oswald-Bold.woff2` | Todo lo que salta en partida ("+N", "-N", "¡ROBO!"), marcador y tiempo |
| `Oswald-Medium.woff2` | Resto del texto |

Las fuentes viejas (`NewRocker`, `LilitaOne`, `Baloo2`) se borran en el bloque 11a de la fase 11, cuando el juego ya no las use.

Godot 4 importa `.woff2` directamente: se cargan como `FontFile` (`load("res://assets/fonts/...")`).
