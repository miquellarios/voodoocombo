# VoodooCombo

Party game de arena: recoge doblones, encadena combos y usa el dash para robar a tus rivales.
Proyecto Godot 4.7, GDScript, renderizador GL Compatibility y ventana 1280×720.

## Controles

- Mover: WASD, flechas o stick izquierdo.
- Dash: Espacio, Shift o A.
- Usar hechizo: E, Enter o B.
- Pausa: Esc.

## Modos

- **VoodooCombo:** 90 segundos, combo x1–x4, Frenesí al final y gana el mayor marcador.
- **Clásico:** el primero que recoge 15 doblones gana; si se agota el tiempo de 3 minutos, gana el mayor contador.

En esta versión se puede jugar en un PC contra tres bots. Se generan arena, obstáculos, cofres y monedas sin assets externos. Las fuentes externas son opcionales.

## Ejecutar

Abre el proyecto en Godot 4.7 y pulsa F6/F5. Para ejecutar las pruebas de lógica:

```powershell
godot --headless --path . --script res://tests/run_tests.gd
```

La exportación normal de Windows está descrita en `export_presets.cfg` y necesita las plantillas oficiales de Godot. Como este PC no las tenía, `build/` incluye una versión 0.1 arrancable con su PCK y el runtime Godot 4.7.2 al lado; hay que mantener juntos los tres archivos del paquete.

## Estado de la red y entrega

Se añadieron los cimientos ENet, descubrimiento UDP y endpoint HTTP. Aún falta conectar el lobby y la simulación de la partida a snapshots/eventos autoritativos entre clientes; por eso esta versión no se debe presentar como multijugador en red terminado. El endpoint dedicado expone `/status`, `/results` y `/`, pero el proceso dedicado todavía no simula una partida.

Al completar una partida local se guarda un JSON en `user://matches/` y se actualiza el perfil en `user://profile.cfg`. No se generaron capturas ni fuentes tipográficas porque no estaban en el kit.
