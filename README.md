# VoodooCombo 0.14.0

Party game de arena para 2–4 jugadores, con tres modos, bots y partidas en red por salas. Proyecto Godot 4.7.2, GDScript tipado y renderizador GL Compatibility.

## Ejecutar

Abre `project.godot` con Godot 4.7.2 y pulsa F6/F5. El servidor dedicado se puede iniciar con:

```powershell
godot --headless --path . -- --server --port 7777
```

Para jugar desde el paquete Windows, extrae `build/VoodooCombo-v0.14.0-Windows.zip` y ejecuta `VoodooCombo.exe`. El archivo incluye `LEEME.txt` y `servidor.bat`.

## Controles

- Mover: WASD, flechas o stick izquierdo.
- Dash: Espacio, Shift o A.
- Usar hechizo: E o B.
- Pausa/menú: Esc o Start.

## Modos

- **VoodooCombo:** gana quien tenga más doblones al terminar el tiempo.
- **Último en Pie:** sobrevive a tres costuras; al mejor de tres rondas.
- **Codicia 2v2:** deposita los doblones en el cofre de tu equipo.

## Pruebas

```powershell
godot --headless --path . --script res://tests/run_tests.gd
```

La bitácora de cambios y pruebas está en `docs/BITACORA.md`. Las instrucciones para alojar un servidor externo están en `docs/DESPLIEGUE.md`.
