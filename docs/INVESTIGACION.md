# Investigación propia

> El profesorado pregunta si investigasteis las tecnologías que propuso la IA o si las copiasteis tal cual.
> Para cada una: explicadla con vuestras palabras, haced el experimento propuesto y apuntad la fuente.

| # | Tecnología | Qué hay que entender | Experimento para comprobarlo | Fuente para empezar |
|---|---|---|---|---|
| 1 | Godot 4 y GDScript | Por qué Godot y no la versión web con Node | Comparad lo que pedía el PDF inicial con lo que da Godot (red, sonido, exportar) | Documentación oficial de Godot |
| 2 | ENet y RPC de Godot | Qué es un mensaje fiable y uno no fiable, y por qué las posiciones van por el no fiable | Mandad las posiciones como fiables y comparad cómo se nota | Godot Docs, "High-level multiplayer" |
| 3 | Servidor autoritativo | Por qué el servidor decide los doblones y los golpes, y el cliente solo su movimiento | Intentad "hacer trampa" moviendo vuestro muñeco muy rápido y mirad qué hace el servidor | Godot Docs, "High-level multiplayer" |
| 4 | Interpolación de snapshots | Por qué los demás jugadores se ven 100 ms en el pasado | Bajad el envío a 5 por segundo y comparad con y sin interpolación | Artículos sobre *entity interpolation* en juegos en red |
| 5 | Descubrimiento LAN (UDP broadcast) | Cómo aparecen las salas sin escribir la IP | Probadlo en la red del instituto y en el punto de acceso del móvil | Godot Docs, `PacketPeerUDP` |
| 6 | Endpoint HTTP con `TCPServer` | Cómo funciona una petición HTTP por dentro (línea de petición, cabeceras, JSON) | Abrid `/status` en el navegador y con `curl` | Godot Docs, `TCPServer` y `StreamPeerTCP` |
| 7 | Generación con semilla y simetría | Por qué la misma semilla da la misma arena y para qué sirve el BFS | Jugad dos partidas con la misma semilla | Artículos de generación procedural |
| 8 | Sonido sintetizado | Cómo se crea un sonido con números (onda, frecuencia, envolvente) | Cambiad la frecuencia del *cling* y escuchad la diferencia | Godot Docs, `AudioStreamWAV` |
| 9 | `AGENTS.md` y agentes | Cómo Codex lee las directrices permanentes | Quitad una regla de `AGENTS.md` y mirad si Codex la sigue cumpliendo | Documentación de Codex |
| 10 | Game feel ("juice") | Por qué los pequeños efectos cambian cómo se siente el juego | Desactivad los efectos con "Reducir movimiento" y comparad | Charlas "Juice it or lose it" (Jonasson y Purho) y "The art of screenshake" (Jan Willem Nijman) |
| 11 | Accesibilidad en juegos | Qué pautas cumplimos y cuáles no | Jugad sin color (escala de grises) y solo con teclado | Game Accessibility Guidelines |

---

## Notas por tecnología

Copiad este bloque para cada tecnología que investiguéis.

```
### <Tecnología>
- Qué nos propuso la IA:
- Qué es (con nuestras palabras):
- Experimento y resultado:
- ¿Lo adoptamos tal cual o lo cambiamos? ¿Por qué?
- Fuente:
```
