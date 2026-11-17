# Plan técnico: multijugador PvP de 4 jugadores en Godot 4

**Documento para Claude — especificación, arquitectura y hoja de ruta**

## 0. Objetivo

Diseñar e implementar el multijugador online de un videojuego PvP desarrollado en **Godot 4 para PC**, con estas condiciones:

- Máximo de **4 jugadores por partida**.
- Partidas competitivas PvP.
- Jugadores conectados desde casas y redes diferentes.
- Servidor dedicado y autoritativo: ningún cliente decide por sí mismo los impactos, la vida o el ganador.
- Prioridad: mantener los costes en **0 €**, utilizando software libre/gratuito y niveles gratuitos de servicios externos.
- El proyecto incluye documentación, código, sprites y arenas; la red debe integrarse sin romper la estructura existente.

Este documento es una propuesta técnica inicial. **Antes de modificar el proyecto, inspecciona el repositorio existente**, identifica la versión exacta de Godot, el lenguaje utilizado (GDScript/C#), escenas, scripts, mecánicas y estructura actual. No sobrescribas archivos ni inventes nombres de escenas o nodos que no existan: adapta la propuesta al proyecto real.

---

## 1. Decisión de arquitectura

### Arquitectura recomendada

Utilizar una arquitectura **cliente-servidor con servidor dedicado autoritativo**:

- **Gameplay:** `ENetMultiplayerPeer` de Godot sobre UDP.
- **Servidor de partida:** ejecutable dedicado de Godot en modo headless.
- **Gestión de salas / matchmaking:** inicialmente sencilla; puede añadirse un pequeño servicio HTTPS/WebSocket independiente cuando la conexión básica funcione.
- **Alojamiento principal propuesto:** Oracle Cloud Infrastructure (OCI) Always Free, sujeto a disponibilidad y límites.
- **Pruebas desde un PC propio:** Playit.gg únicamente si su nivel gratuito vigente permite crear un túnel UDP personalizado compatible con el puerto ENet utilizado.
- **Cloudflare:** opcional para un servicio ligero de gestión de salas (API HTTPS y, si las condiciones gratuitas vigentes lo permiten, WebSockets). No utilizar Cloudflare Workers como si fuera un servidor Godot ni asumir que Workers ofrece un proxy UDP genérico para ENet.

### Diagrama lógico

```text
                   SERVICIO DE SALAS (opcional)
                 Cloudflare Worker / API HTTPS
                  crear sala, unirse, consultar
                            |
                            | devuelve IP + puerto
                            v
Jugador 1 ----\
Jugador 2 -----+---- ENet / UDP ----> Servidor Godot dedicado
Jugador 3 -----+                      (Oracle Cloud VM)
Jugador 4 ----/                       Autoridad de la partida
```

El servicio de salas y el servidor de gameplay son responsabilidades distintas. En la primera versión se puede omitir Cloudflare y conectar los clientes directamente a la IP pública y puerto UDP del servidor. Añadir códigos de sala más adelante.

### Por qué ENet para el gameplay

Godot incluye `ENetMultiplayerPeer`, una implementación de `MultiplayerPeer` basada en ENet. ENet utiliza UDP y permite configurar modos de transferencia y canales. Esto encaja mejor con un juego de acción en tiempo real que enviar todos los estados por una conexión TCP/WebSocket fiable y ordenada.

No significa que WebSockets sea incorrecto: `WebSocketMultiplayerPeer` también está integrado en Godot y puede servir para un juego pausado, un lobby o una API de salas. Para este PvP, la recomendación es ENet para el estado frecuente de la partida.

**No mezclar ambos protocolos en el mismo `MultiplayerAPI` esperando que se conecten entre sí.** Si se utiliza WebSocket para salas, será un servicio separado y no sustituirá a ENet en la partida.

---

## 2. Responsabilidad del servidor: autoridad y antitrampas

El servidor debe ser la fuente de verdad de la partida.

| Dato / acción | Autoridad |
|---|---|
| Posición válida del jugador | Servidor |
| Velocidad y límites de movimiento | Servidor |
| Cadencia y disponibilidad de disparo | Servidor |
| Colisiones e impactos | Servidor |
| Vida y daño | Servidor |
| Muertes y reapariciones | Servidor |
| Puntuación y resultado | Servidor |
| Inicio y fin de la partida | Servidor |
| Entrada de controles | Cliente, validada por servidor |

Los clientes envían **intenciones** (por ejemplo, teclas pulsadas, dirección de apuntado o solicitud de disparo), no resultados finales como “he acertado” o “mi vida ahora es 100”.

Reglas de seguridad:
1. No confiar en un `player_id` enviado por el cliente. Obtener el emisor con `multiplayer.get_remote_sender_id()` en el servidor.
2. Validar que el jugador está conectado, vivo y en la partida.
3. Validar frecuencia de disparo, velocidad, límites del mapa y estados permitidos.
4. Calcular impactos en el servidor.
5. No permitir que un cliente invoque RPC administrativos.
6. Limitar el tamaño y frecuencia de mensajes.
7. No guardar contraseñas, tokens o secretos en el cliente.
8. Para una primera versión, usar identificadores de peer asignados por Godot; posteriormente añadir autenticación si hace falta.

La autoridad del servidor no elimina todos los trucos posibles, pero reduce la confianza depositada en los clientes.

---

## 3. Servicios gratuitos: qué hace cada uno y qué no hace

### A. Oracle Cloud Infrastructure (OCI) — alojamiento principal

**Uso propuesto:** ejecutar una VM Linux y alojar el servidor Godot headless.

La oferta Always Free de Oracle incluye recursos de cómputo Ampere A1 sujetos a cuotas, región, disponibilidad y condiciones vigentes. Oracle publica una asignación gratuita equivalente, dentro de sus límites, a hasta 2 OCPU y 12 GB de memoria para Ampere A1. Puede aparecer el error de falta de capacidad en una región.

Pasos generales:
1. Crear una cuenta OCI y revisar cuidadosamente el tipo de cuenta y recursos seleccionados.
2. Elegir la región de inicio (home region) y comprobar la disponibilidad de recursos Always Free.
3. Crear una instancia Linux compatible con la arquitectura seleccionada.
4. Elegir únicamente recursos identificados como Always Free y mantenerse dentro de sus cuotas.
5. Crear reglas de red para permitir el puerto del juego **en UDP**. Ejemplo: UDP `2456`.
6. Configurar también el firewall del sistema operativo (`ufw` o equivalente).
7. Conectarse por SSH con claves; no habilitar acceso root por contraseña.
8. Instalar o subir la exportación Linux del servidor Godot.
9. Ejecutar el servidor como servicio `systemd`.
10. Comprobar desde una red externa que el puerto UDP es accesible.

**Precauciones importantes:**
- Always Free no garantiza capacidad disponible en todas las regiones ni en todo momento.
- No seleccionar recursos de pago por error.
- Configurar presupuestos, alertas y límites de gasto cuando estén disponibles.
- Revisar la página de precios y las condiciones oficiales antes de crear la VM.
- No prometer que el servicio será gratuito para siempre o que la instancia nunca será recuperada/suspendida.
- Confirmar compatibilidad de la exportación del servidor con la arquitectura de la VM (por ejemplo, x86_64 frente a ARM64). No asumir que un binario exportado para una arquitectura funciona en otra.

Página oficial: https://www.oracle.com/cloud/free/
Recursos Always Free: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm

### B. Cloudflare — servicio opcional de salas

**Uso propuesto:** alojar una API ligera de gestión de salas, no el servidor de juego.

Posibles endpoints:
- `POST /rooms` — crear sala.
- `POST /rooms/{code}/join` — solicitar unirse.
- `GET /rooms/{code}` — consultar estado básico.
- `POST /rooms/{code}/leave` — abandonar sala.

La API podría devolver:
- Código de sala.
- Dirección pública del servidor ENet.
- Puerto UDP.
- Estado de la sala y número de jugadores.

Se puede estudiar Cloudflare Workers para endpoints HTTPS y, si la necesidad lo justifica, WebSockets / Durable Objects para mantener estado de salas. **Comprobar las cuotas gratuitas actuales de Workers y Durable Objects** antes de diseñarlo. El plan gratuito tiene límites de solicitudes/CPU/almacenamiento y puede rechazar operaciones al superar la cuota. Algunas funciones y planes han cambiado con el tiempo.

Limitaciones:
- Workers no ejecuta directamente un proceso Godot headless persistente.
- No asumir que Cloudflare Workers puede recibir y retransmitir el tráfico UDP de ENet.
- No usarlo como sustituto de la VM de Oracle.
- Para la primera versión, la API de salas es opcional: se puede empezar con IP y puerto manuales y añadir códigos de sala cuando el juego ya funcione.

Precios y límites:
- https://developers.cloudflare.com/workers/platform/pricing/
- https://developers.cloudflare.com/workers/platform/limits/
- https://developers.cloudflare.com/durable-objects/platform/pricing/
- https://developers.cloudflare.com/durable-objects/platform/limits/

### C. Playit.gg — pruebas desde un PC propio

**Uso propuesto:** exponer temporalmente un servidor ENet que corre en un PC de desarrollo, sin configurar manualmente el router.

Flujo:
1. Ejecutar el servidor Godot en el PC anfitrión.
2. Ejecutar el agente Playit.gg.
3. Configurar un túnel UDP hacia la dirección/puerto local del servidor.
4. Compartir con los otros jugadores el endpoint público asignado.
5. Probar la conexión desde redes externas.

**Condición importante:** comprobar antes de depender de ello que el plan gratuito vigente permite un túnel UDP personalizado para una aplicación Godot/ENet. La página pública de Playit enumera juegos compatibles y opciones de túnel; no asumir que cualquier protocolo/puerto personalizado está incluido en el nivel gratuito. Si no está disponible gratis, no contratar Premium: utilizar la VM OCI o una prueba en LAN.

Playit.gg no es el servidor de juego. Solo proporciona un camino de acceso al servidor que sigue ejecutándose en el PC anfitrión. Si el PC se apaga, el servidor deja de estar disponible.

Página oficial: https://playit.gg/pricing

### Estrategia de coste cero

1. **Desarrollo local:** Godot + ENet en LAN, coste 0 €.
2. **Pruebas remotas tempranas:** Playit.gg solo si el túnel UDP personalizado está incluido en el plan gratuito vigente.
3. **Pruebas y alojamiento remoto:** OCI Always Free, si hay capacidad y la cuenta cumple las condiciones.
4. **Salas con código:** comenzar sin servicio externo; más adelante estudiar Cloudflare Workers en el nivel gratuito vigente.
5. No activar servicios de pago, no actualizar a planes de pago y no introducir una tarjeta/upgrade sin autorización explícita del usuario.

“Gratis” depende de límites, disponibilidad, requisitos de cuenta y cambios de los proveedores. Verificar siempre antes de desplegar.

---

## 4. Diseño de la conexión ENet en Godot

### Configuración inicial

- Puerto sugerido: `2456` (configurable).
- Protocolo: UDP.
- Máximo de clientes: `4`.
- Servidor dedicado separado de los cuatro clientes.
- Los cuatro clientes se conectan a la IP pública y puerto del servidor.

En Godot, el servidor puede inicializarse con:

```gdscript
var peer := ENetMultiplayerPeer.new()
var error := peer.create_server(2456, 4)

if error != OK:
    push_error("No se pudo crear el servidor: %s" % error)
    return

multiplayer.multiplayer_peer = peer
```

Cliente:

```gdscript
var peer := ENetMultiplayerPeer.new()
var error := peer.create_client(server_ip, 2456)

if error != OK:
    push_error("No se pudo iniciar la conexión: %s" % error)
    return

multiplayer.multiplayer_peer = peer
```

Conectar y gestionar señales:
- `multiplayer.peer_connected`
- `multiplayer.peer_disconnected`
- `multiplayer.connected_to_server`
- `multiplayer.connection_failed`
- `multiplayer.server_disconnected`

No limitarse a imprimir “conectado”: actualizar la interfaz, crear/eliminar el jugador y tratar errores.

### Ejemplo de esqueleto de servidor

Este código es orientativo. Adaptarlo a los nodos y escenas reales del proyecto:

```gdscript
extends Node

const PORT := 2456
const MAX_CLIENTS := 4

func _ready() -> void:
    if not multiplayer.is_server():
        start_server()

func start_server() -> void:
    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(PORT, MAX_CLIENTS)

    if error != OK:
        push_error("Error al iniciar ENet: %s" % error)
        return

    multiplayer.multiplayer_peer = peer
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    print("Servidor escuchando en UDP %d" % PORT)

func _on_peer_connected(peer_id: int) -> void:
    print("Conectado: ", peer_id)
    # Validar capacidad/estado y crear el jugador correspondiente.

func _on_peer_disconnected(peer_id: int) -> void:
    print("Desconectado: ", peer_id)
    # Eliminar su personaje y actualizar la sala/partida.
```

**Atención:** el ejemplo es un punto de partida, no un servidor listo para producción. Revisar cómo se determina el modo servidor y cómo se ejecuta la escena dedicada en el proyecto real. Evitar que cada cliente intente arrancar un servidor.

### Ejemplo de RPC autoritativo para disparar

```gdscript
@rpc("any_peer", "reliable")
func request_shoot(direction: Vector2) -> void:
    if not multiplayer.is_server():
        return

    var sender_id := multiplayer.get_remote_sender_id()

    # 1. Buscar el jugador asociado a sender_id.
    # 2. Comprobar que existe y está vivo.
    # 3. Validar dirección, cadencia y estado.
    # 4. Calcular el disparo/impacto en el servidor.
    # 5. Actualizar vida y puntuación en el servidor.
    # 6. Replicar el resultado a los clientes.
```

No copiar el ejemplo sin implementar las comprobaciones. Para acciones frecuentes, estudiar el modo de transferencia y los canales ENet. Los eventos críticos (por ejemplo, resultado de una muerte o inicio de ronda) deben enviarse de forma fiable; los datos de movimiento pueden necesitar un tratamiento distinto para no acumular información obsoleta.

---

## 5. Sincronización de jugadores

Usar las herramientas de Godot según la necesidad:

- `MultiplayerSpawner`: creación y eliminación replicada de jugadores/nodos, si encaja con la estructura de escenas.
- `MultiplayerSynchronizer`: replicación de propiedades autorizadas por el servidor.
- RPC: acciones y eventos como disparar, recibir daño, morir, iniciar ronda o actualizar puntuación.

No sincronizar indiscriminadamente todos los nodos ni cada propiedad en cada frame. Definir qué datos son necesarios y con qué frecuencia.

Para movimiento:
1. El cliente lee controles.
2. Envía inputs al servidor.
3. El servidor valida y simula el movimiento.
4. El servidor publica el estado autoritativo.
5. Los clientes interpolan estados para suavizar la representación.
6. Si el juego lo necesita, estudiar predicción y reconciliación más adelante.

La implementación concreta depende de si el juego es top-down, plataformas, arena 2D/3D, por turnos, etc. Inspeccionar las mecánicas existentes antes de elegir el modelo de movimiento.

---

## 6. Sistema de salas: hacerlo en dos fases

### Fase 1 — conexión manual

Antes de implementar códigos:
- Campo de IP/host.
- Puerto configurable o constante.
- Botón “Conectar”.
- Mostrar estado de conexión.
- Mostrar lista de jugadores conectados.
- Permitir iniciar una partida cuando se cumplan las reglas.

Esto reduce variables y permite validar primero el transporte de red.

### Fase 2 — código de sala

Cuando ENet funcione:
1. Un jugador solicita crear una sala.
2. El servicio asigna un código aleatorio no predecible.
3. La sala registra el endpoint del servidor, estado y jugadores.
4. Los demás jugadores introducen el código.
5. El servicio devuelve endpoint y datos mínimos de conexión.
6. El cliente conecta directamente al servidor ENet.
7. El servidor valida que la sala admite al jugador.
8. Al empezar la partida, se bloquean nuevas entradas o se aplica la política definida.

Para una primera versión se puede implementar un servicio HTTP sencillo. Si se utiliza Cloudflare Workers, mantenerlo como plano de control; no enviar por él los paquetes de movimiento y combate.

Considerar que un código de sala no es una medida de seguridad suficiente. Añadir expiración, límite de intentos y validación de la capacidad.

---

## 7. Ejecutar Godot como servidor dedicado

Objetivo: exportar un ejecutable Linux dedicado y ejecutarlo sin interfaz gráfica.

Godot dispone de modo headless y opciones de exportación para servidores dedicados. La forma exacta depende de la versión de Godot y de si el proyecto usa GDScript o C#.

Tareas:
1. Inspeccionar versión y configuración de exportación del proyecto.
2. Crear un preset de exportación Linux para servidor dedicado.
3. Separar la escena de arranque del servidor de la escena del cliente si es necesario.
4. Evitar cargar menús, HUD, audio y recursos visuales que el servidor no necesita.
5. Mantener la lógica de gameplay compartida cuando sea seguro y práctico.
6. Exportar para la arquitectura correcta de la VM.
7. Probar localmente con el modo headless antes de subirlo.
8. Configurar reinicio automático y logs.

Ejemplo conceptual de ejecución:

```bash
./mi_juego_server.x86_64 --headless
```

No asumir que ese nombre de ejecutable o esa opción exacta coinciden con el proyecto: utilizar el archivo generado por el preset real.

### Servicio systemd (plantilla)

Crear un usuario Linux sin privilegios administrativos para el servidor y adaptar las rutas:

```ini
[Unit]
Description=Godot Dedicated Game Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=godotserver
WorkingDirectory=/opt/godot-server
ExecStart=/opt/godot-server/mi_juego_server.x86_64 --headless
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Cambiar `mi_juego_server.x86_64` por el nombre real del ejecutable. No ejecutar el juego como root.

---

## 8. Despliegue en Oracle Cloud: lista de tareas

1. Crear la cuenta y confirmar la home region.
2. Revisar qué recursos están marcados como Always Free.
3. Crear VM Linux con recursos dentro de la cuota gratuita.
4. Anotar IP pública, usuario y arquitectura.
5. Añadir regla de entrada UDP para el puerto del juego (por ejemplo `2456`).
6. Añadir regla equivalente en firewall del sistema operativo.
7. Conectarse por SSH con una clave privada protegida.
8. Crear usuario `godotserver`.
9. Subir el ejecutable y los recursos necesarios.
10. Probar ejecución manual.
11. Crear servicio `systemd`.
12. Comprobar logs y reinicio.
13. Conectar desde un PC fuera de la red de la VM.
14. Medir estabilidad con cuatro jugadores.

**No abrir TCP si el gameplay utiliza solo ENet/UDP.** Si más adelante se añade una API HTTPS o WebSocket, abrir/configurar los puertos TCP correspondientes de forma separada.

---

## 9. Seguridad y operación

- No exponer SSH a todo Internet si puede restringirse a las IP necesarias.
- Usar claves SSH.
- Mantener Linux y Godot actualizados.
- Abrir solo los puertos necesarios.
- No guardar claves privadas dentro del repositorio Git.
- No incluir tokens de Cloudflare, OCI o Playit en el proyecto.
- Añadir logs de conexión, desconexión, errores y fin de partida.
- Añadir límite de frecuencia a RPC.
- Validar todos los datos recibidos.
- Definir qué ocurre si el servidor se cae.
- Definir qué ocurre si un jugador se desconecta a mitad de partida.
- No confiar en el cliente para determinar el ganador.

---

## 10. Plan de implementación por hitos

No desarrollar todo a la vez. Completar y probar cada hito antes de continuar.

### Hito 0 — inspección del proyecto
- Revisar árbol de carpetas.
- Identificar versión de Godot y lenguaje.
- Identificar escena principal, escenas de jugador y arenas.
- Identificar cómo funciona actualmente el movimiento y el combate.
- Detectar Autoloads y dependencias.
- Proponer los cambios mínimos antes de editar.

**Entrega:** resumen de arquitectura actual y plan de cambios concreto.

### Hito 1 — conexión LAN
- Crear gestor de red.
- Implementar servidor ENet.
- Implementar cliente ENet.
- Conectar dos instancias en la misma LAN.
- Mostrar conexiones y desconexiones.

**Criterio de aceptación:** dos instancias se conectan y el servidor identifica cada peer.

### Hito 2 — cuatro jugadores
- Limitar a cuatro clientes.
- Crear jugador para cada peer.
- Asignar identidad desde el servidor.
- Eliminar jugador al desconectar.
- Evitar IDs duplicados y jugadores fantasma.

**Criterio de aceptación:** cuatro clientes conectan; el quinto es rechazado de forma controlada.

### Hito 3 — sincronización de gameplay
- Sincronizar movimiento.
- Sincronizar animaciones/estado visual necesario.
- Sincronizar disparos y resultados.
- Validar movimiento y combate en el servidor.
- Sincronizar vida, muerte y puntuación.

**Criterio de aceptación:** los cuatro jugadores observan un estado coherente y el servidor decide los resultados.

### Hito 4 — partida PvP completa
- Inicio de ronda.
- Reglas de victoria.
- Reinicio de ronda.
- Desconexión y abandono.
- Pantalla de resultados.

**Criterio de aceptación:** se puede completar una partida PvP de principio a fin.

### Hito 5 — pruebas por Internet
- Probar Playit.gg si el plan gratuito permite UDP personalizado.
- Alternativamente desplegar en OCI.
- Configurar UDP y firewall.
- Probar desde redes distintas.
- Registrar latencia, pérdida de conexión y errores.

**Criterio de aceptación:** cuatro clientes externos pueden jugar una partida completa.

### Hito 6 — salas
- Crear sala.
- Generar código.
- Unirse por código.
- Mostrar jugadores en lobby.
- Iniciar cuando se cumplan las condiciones.

**Criterio de aceptación:** cuatro jugadores pueden reunirse sin escribir manualmente la IP.

### Hito 7 — endurecimiento
- Validación de RPC.
- Límites de frecuencia.
- Gestión de reconexión o abandono.
- Logs.
- Reinicio del servidor.
- Comprobación de cuotas y costes de los proveedores.

---

## 11. Pruebas necesarias

| Prueba | Resultado esperado |
|---|---|
| Un cliente conecta | El servidor registra su peer |
| Cuatro clientes conectan | Todos aparecen una sola vez |
| Quinto cliente intenta entrar | Se rechaza correctamente |
| Cliente se desconecta | Se elimina su jugador |
| Servidor se cierra | Clientes muestran desconexión |
| Dos jugadores disparan | El servidor calcula los impactos |
| Cliente envía datos inválidos | El servidor los rechaza |
| Cliente intenta modificar vida | El servidor ignora/rechaza la petición |
| Partida termina | Todos reciben el mismo resultado |
| Conexión desde otra red | El cliente llega al servidor público |

---

## 12. Estructura de carpetas sugerida

No imponer esta estructura sin inspeccionar el proyecto. Adaptarla a la organización existente.

```text
res://
├── scenes/
│   ├── menu/
│   ├── lobby/
│   └── game/
├── scripts/
│   ├── network/
│   │   ├── NetworkManager.gd
│   │   ├── ServerManager.gd
│   │   └── LobbyManager.gd
│   ├── player/
│   └── game/
├── assets/
│   ├── sprites/
│   └── arenas/
└── docs/
    └── multiplayer.md
```

Responsabilidades sugeridas:
- `NetworkManager`: conectar/desconectar clientes y mantener estado de conexión.
- `ServerManager`: inicializar servidor, aceptar/rechazar peers y gestionar el ciclo de vida de la partida.
- `LobbyManager`: jugadores en espera y reglas de inicio.
- `GameManager`: reglas de la partida, estado, puntuación y victoria.
- `Player`: lógica de movimiento y acciones, separando claramente la autoridad del servidor de la entrada del cliente.

Evitar crear varios Autoloads que gestionen la misma conexión. Debe existir una única fuente de verdad para el estado de red en cada proceso.

---

## 13. Instrucciones para Claude al trabajar en el repositorio

1. **Primero inspecciona, después modifica.** Revisa el repositorio completo y resume cómo está construido.
2. Pregunta si falta información imprescindible, pero no preguntes por detalles que puedas descubrir leyendo el proyecto.
3. No reescribas el juego ni cambies sus mecánicas para introducir la red.
4. No reemplaces sprites, arenas ni documentación existente.
5. Implementa por hitos pequeños y explica qué archivos vas a tocar antes de cambios grandes.
6. Mantén el código adecuado al nivel y estilo del proyecto; evita introducir frameworks innecesarios.
7. No inventes APIs de Godot. Comprueba los nombres y firmas contra la documentación de la versión exacta del proyecto.
8. No añadas Cloudflare, Playit ni servicios externos al gameplay hasta que la conexión LAN ENet funcione.
9. No despliegues recursos de pago, no aceptes upgrades ni actives servicios facturables.
10. Si un plan gratuito no permite una función necesaria, detente y explica la limitación; no elijas un plan de pago automáticamente.
11. Después de cada hito, indica los archivos modificados, cómo ejecutar la prueba y qué resultado debería verse.
12. No declares una fase terminada sin ejecutar o describir una prueba reproducible.

### Primera tarea que debe realizar Claude

**No empieces implementando todo el multijugador.** Empieza inspeccionando el repositorio y entrega:

- Versión de Godot.
- Lenguaje y estructura del proyecto.
- Escena principal y escenas del jugador.
- Cómo están implementados actualmente movimiento, disparos, vida y colisiones.
- Qué partes pueden reutilizarse en un servidor dedicado.
- Qué archivos habría que crear o modificar.
- Riesgos o incompatibilidades detectados.
- Primer plan de implementación del Hito 1.

Después de revisar ese informe, comienza el Hito 1: conexión ENet entre dos instancias en LAN.

---

## 14. Documentación oficial y enlaces

- Godot — ENetMultiplayerPeer: https://docs.godotengine.org/es/4.x/classes/class_enetmultiplayerpeer.html
- Godot — Multijugador de alto nivel: https://docs.godotengine.org/es/4.x/tutorials/networking/high_level_multiplayer.html
- Godot — WebSocketMultiplayerPeer: https://docs.godotengine.org/en/latest/classes/class_websocketmultiplayerpeer.html
- Oracle Cloud Free Tier: https://www.oracle.com/cloud/free/
- Oracle Always Free Resources: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- Cloudflare Workers Pricing: https://developers.cloudflare.com/workers/platform/pricing/
- Cloudflare Workers Limits: https://developers.cloudflare.com/workers/platform/limits/
- Cloudflare Durable Objects Pricing: https://developers.cloudflare.com/durable-objects/platform/pricing/
- Playit.gg Pricing: https://playit.gg/pricing

**Nota final:** los precios, cuotas y condiciones de los planes gratuitos pueden cambiar. Verificarlos en las páginas oficiales antes de crear recursos. La arquitectura no debe depender de que Playit.gg o Cloudflare ofrezcan gratuitamente una función concreta: el camino principal de gameplay es ENet/UDP hacia el servidor dedicado, y OCI Always Free es una opción de alojamiento condicionada a sus límites y disponibilidad.
