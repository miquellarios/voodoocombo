# VoodooCombo — Ajedrez Vudú Modular

> Propuesta de diseño: ajedrez con energía, ejércitos personalizables, poderes y control del ritmo.
> Sustituye a las reglas de "un muñeco por jugador" del AGENTS.md anterior. Del diseño previo se mantienen la parte visual, la red y el endpoint.

---

## 0. Resumen

**La idea:** cada jugador lleva un **ejército de muñecos vudú** (rey, dama, torres...) sobre un tablero 8×8 con terreno aleatorio. Antes de la partida montas tu ejército con un presupuesto de puntos y les asignas rasgos de cinco escuelas de magia. Durante la partida acumulas **energía (máx. 10)** para usar poderes. Ganas si capturas al rey rival o si reúnes 4 de los 6 doblones del tablero.

**Diseño por capas.** Cada configuración contiene a la anterior. Podéis parar en cualquiera y tendréis un juego completo:

| | A · Ligera | **B · Modular (recomendada)** | C · Competitiva |
|---|---|---|---|
| Ejército | 3 ejércitos predefinidos | Constructor por puntos + ejércitos predefinidos | + draft alterno con baneos |
| Rasgos | 10 (2 por escuela) | 20 + 2 neutrales + 5 rituales | Todos + niveles 3 |
| Energía | Global | Global + altares + veteranía por pieza | + objetivos de tablero |
| Información | Todo visible | Parcial (rasgos ocultos hasta usarse) | + despliegue oculto |
| Ritmo | Reloj + Luna de Sangre + límite de rondas | + Rituales + Marea Vudú + mantenimiento | + modos de victoria configurables |
| Complejidad | Baja | Media | Alta |

---

## 1. Base del juego

### 1.1 Tablero (8×8 con semilla)
- **Simetría:** simétrico por rotación de 180°: la casilla (x, y) es igual que (7−x, 7−y). Así ningún jugador sale con ventaja.
- **Zonas:**
  - Filas 1-2: despliegue de P1.
  - Filas 7-8: despliegue de P2.
  - Filas 3-6: terreno generado al azar.
- **Terreno** (siempre en parejas simétricas):

| Elemento | Cantidad | Regla |
|---|---|---|
| Tótem | 4 | Bloquea como una pieza que no se puede capturar. El caballo lo salta |
| Altar | 2 | Si lo ocupas al empezar tu turno: +1⚡ |
| Doblón | 6 | La pieza que **termina** su movimiento encima lo recoge |
| Ciénaga | 0-4 | Las piezas que se deslizan (torre, alfil, dama) se paran al entrar |

- **Validación:** con BFS se comprueba que todos los altares y doblones son alcanzables. Si no, se regenera con semilla+1.
- **Encaje con el enunciado:** el tablero es aleatorio en cada partida, los jugadores aparecen en su zona y hay un objetivo que conseguir.

### 1.2 Piezas
Las piezas tienen el **movimiento clásico** del ajedrez, con algunas simplificaciones:
- **Sin enroque:** lo sustituye el rasgo Intercambio de Sombras.
- **Sin captura al paso.**
- **Promoción:** al llegar a la última fila, el peón asciende a caballo, alfil, torre o dama.

**Decisión recomendada: se gana capturando al Rey, no dando jaque mate.**
- Con poderes que teletransportan, congelan o intercambian piezas, calcular jugadas legales y jaque mate se vuelve muy complejo y da muchos bugs.
- Capturar al Rey es más simple para el servidor y hace las partidas más rápidas.
- El juego avisa con **"¡Jaque!"** cuando tu rey puede ser capturado en la siguiente jugada. El aviso solo tiene en cuenta los movimientos normales, así que los poderes todavía pueden sorprender.

### 1.3 Victoria

| Condición | Detalle |
|---|---|
| **Regicidio** | Capturas al Rey rival |
| **Botín** | Reúnes 4 de los 6 doblones |
| **Reloj** | Al rival se le acaba el tiempo |
| **Abandono** | El rival se desconecta y no vuelve en 20 s, o se rinde |
| **Límite** | En la ronda 30 gana quien tenga más puntos: material vivo + 3 por doblón. Si empatan, gana quien tenga más tiempo de reloj |

La sala puede elegir el modo de victoria: **Regicidio** (solo rey) o **Botín** (rey o doblones). Por defecto, Botín, porque encaja con el "objetivo" del enunciado y con los doblones que ya teníamos.

---

## 2. El recurso: Energía y Veteranía

### 2.1 Opciones evaluadas

| Modelo | Cómo funciona | A favor | En contra | Complejidad |
|---|---|---|---|---|
| **Global** | Una barra por jugador (0-10) | Se lee de un vistazo, decisiones de gasto claras | Puede hacer bola de nieve | Baja |
| **Por pieza** | Cada pieza acumula y gasta lo suyo | Muy táctico | 8-10 barras en pantalla, ilegible en blitz. Perder una pieza cargada frustra | Alta |
| **Por tablero** | Solo se gana con capturas o altares | Fuerza el choque | Sin capturas no hay poderes y el inicio es lento | Media |
| **Híbrido (recomendado)** | Energía global para gastar + Veteranía por pieza (no se gasta, sube de nivel) + bonus del tablero | Lo mejor de cada uno | Una regla más | Media |

### 2.2 Energía (⚡, global, máximo 10)

| Fuente | ⚡ |
|---|---|
| Al empezar la partida | 2 (el segundo jugador, 3, para compensar empezar después) |
| Al inicio de tu turno | +1 (+2 desde la Luna de Sangre) |
| Capturar un peón o una pieza menor | +1 |
| Capturar una torre o la dama | +2 |
| Ocupar un altar al inicio de tu turno | +1 por altar |
| Recoger un doblón | +1 |

- **Tope:** 10. Lo que pase de 10 se pierde, así que compensa gastar en vez de acumular.
- **Costes de referencia:** poderes básicos 2⚡, medios 3⚡, fuertes 4⚡, Ritual 10⚡ (toda la barra).
- **Ritmo resultante:** al principio un poder cada 2-3 turnos; con la Luna de Sangre, casi uno por turno.

### 2.3 Veteranía (XP por pieza)
- **Cómo se gana XP:** captura +1, doblón +1, sobrevivir a un ataque (Corteza o Esquiva) +1.
- **Con 2 XP la pieza sube a Nivel 2** (se marca con una estrella cosida):
  - Si tiene rasgo, el rasgo pasa a su versión **Nv2**.
  - Si no tiene rasgo, gana *Veterana*: cuando captura, +1⚡ extra.
  - Si es un peón, **asciende en el acto** a caballo o alfil.
- **En la configuración C** hay un Nivel 3 con 4 XP.

---

## 3. Personalización previa (ejército)

### 3.1 Presupuesto: 32 puntos

| Pieza | Coste | Límite |
|---|---|---|
| Rey | 0 | Obligatorio, 1 |
| Peón | 1 | Máx. 6 |
| Caballo / Alfil | 3 | Máx. 2 de cada |
| Torre | 5 | Máx. 2 |
| Dama | 9 | Máx. 1 |
| Rasgo | 1-3 | Máx. 5 por ejército |

Las piezas cuestan su **valor clásico del ajedrez**. Un mismo presupuesto sirve para piezas y rasgos, lo que obliga a elegir entre **más piezas o piezas más fuertes**.

### 3.2 Ranuras de rasgo por pieza
- **Peón:** 1 ranura, solo rasgos de coste 1.
- **Caballo, alfil, torre y rey:** 1 ranura.
- **Dama:** 2 ranuras.
- La columna "Piezas" del catálogo (§4.3) indica qué pieza puede llevar cada rasgo.

### 3.3 Escuelas y sinergias
Todos los rasgos (salvo los neutrales) pertenecen a una de cinco escuelas. Si llevas **3 rasgos de la misma escuela**, consigues su bonus:

| Escuela | Rol | Inspiración | Bonus con 3 rasgos |
|---|---|---|---|
| 🌳 Bosque Antiguo | Defensa | Ents, Lothlórien, druidas | Tus efectos defensivos no pagan mantenimiento |
| 🌑 Sombra | Desplazamiento | Pícaros, Paso de las Sombras | Tus rasgos no muestran ni siquiera su escuela hasta que se activan |
| ❄️ Escarcha | Control | Caballero de la Muerte | Tus congelaciones duran +1 turno |
| ✨ Arcano | Manipulación del tablero | Magos, Magic | +2⚡ iniciales y tus reactivas cuestan 1⚡ menos |
| 🔥 Dragón | Agresión y final de partida | Smaug, dragones | Cada captura da +1⚡ adicional |

- **Rituales:** solo puedes llevar el Ritual de una escuela de la que tengas al menos 2 rasgos. Solo se lleva uno por ejército.
- **Accesibilidad:** cada escuela tiene un icono con forma propia (árbol, luna, copo, estrella, llama), así que no se distinguen solo por el color.

### 3.4 Información visible u oculta

| Opción | El rival ve | A favor | En contra |
|---|---|---|---|
| Abierta | Todo: piezas, rasgos, ritual | Estrategia pura, simple de programar | Sin sorpresa |
| **Parcial (recomendada)** | Piezas, qué piezas tienen rasgo y su escuela, un sello "?" en las piezas con reactiva armada y la escuela del ritual | Hay faroles y se puede leer al rival | El servidor tiene que filtrar el estado |
| Oculta | Solo las piezas, y el despliegue se hace a ciegas (estilo Stratego) | Mucho juego mental | Complejo, partidas más largas |

- **Siempre ocultas:** la posición de las runas.
- **Revelado:** un rasgo queda a la vista para siempre la primera vez que se activa.
- **Contrapesos:** *Ojo del Vigía* revela lo que hay cerca. *Sombra ×3* lo oculta todavía más.

### 3.5 Cómo se elige el ejército

| Formato | Cómo funciona | Cuándo usarlo |
|---|---|---|
| **Ejércitos predefinidos** | 3 plantillas listas para jugar | Primera partida y configuración A |
| **Constructor** | Se monta en el menú Mazo y se guarda en el perfil. La formación se guarda con el ejército | Configuración B |
| **Draft alterno** | En la sala, cada jugador banea 1 rasgo del rival y después ajustan 2 rasgos por turnos (60 s) | Modo torneo, configuración C |
| **Despliegue Caos** | El servidor coloca tu ejército al azar en tus 2 filas, con el Rey siempre en la fila de atrás (como el ajedrez 960) | Modo alternativo y más aleatorio |

### 3.6 Ejércitos predefinidos (32 puntos cada uno)

| Ejército | Piezas (pts) | Rasgos (pts) | Escuela ×3 | Ritual |
|---|---|---|---|---|
| **Corte de Escarcha** (control) | D, T, A, C, 3P (23) | Maldición Ovina (D), Runa de Escarcha (A), Toque Helado (C), Contrahechizo (R) (9) | ❄️ | Invierno Eterno |
| **Horda del Dragón** (agresión) | 2T, 2C, 5P (21) | Aliento de Dragón (T), Represalia Ígnea (T), Frenesí (C), Tributo del Dragón (C), Botas de Montaraz (P) (11) | 🔥 | Anillo de Poder |
| **Sombras del Bosque** (movilidad) | D, 2A, C, 4P (22) | Corteza de Ent (R), Capa Élfica (A), Paso Sombrío (A), Esquiva Sombría (C), Botas de Montaraz (P) (10) | 🌑 | Asesinato en la Sombra |

---

## 4. Poderes

### 4.1 Tipos de activación

| Tipo | Cómo funciona |
|---|---|
| **P · Pasiva** | Siempre activa. No gasta energía, pero cuesta más puntos en el ejército |
| **A · Activa** | Se usa en tu turno pagando ⚡. Tiene cooldown en turnos propios |
| **R · Reactiva** | Se "arma" en tu turno pagando ⚡ y se dispara sola en el turno del rival cuando se cumple su condición. Máximo 2 armadas a la vez. Va ligada a su pieza: si la pieza muere, la reactiva se pierde |
| **U · Ritual** | Golpe de final de partida: 10⚡, una vez por partida, a partir de la ronda 8 |

### 4.2 Estructura del turno
1. **Inicio del turno:**
   - Ganas energía (ingreso y altares).
   - Pagas el mantenimiento.
   - Bajan los cooldowns y las duraciones.
   - Si toca, avanza la Marea.
2. **Acciones** (en el orden que quieras):
   - **1 movimiento.**
   - **1 poder:** usar una activa, armar una reactiva o lanzar el Ritual.
   - Los poderes que **mueven tu pieza** (Paso Sombrío, Portal, Intercambio) **sustituyen al movimiento**: gastan el poder y el movimiento del turno.
3. **Fin del turno:** se suma el incremento del reloj.

### 4.3 Catálogo
Piezas: P peón, C caballo, A alfil, T torre, D dama, R rey. "Pts" es lo que cuesta en el ejército.

#### 🌳 Bosque Antiguo (defensa)

| Rasgo | Tipo | Piezas | Pts | ⚡ | CD | Efecto | Nv2 |
|---|---|---|---|---|---|---|---|
| Corteza de Ent | P | T, R | 3 | — | — | Sobrevive a la primera captura: el atacante vuelve a su casilla y la corteza se rompe | Se regenera una vez, 6 turnos después |
| Capa Élfica | A | C, A, D | 2 | 2 | 4 | No puede ser capturada ni afectada por poderes hasta tu próximo turno | Protege también a una pieza adyacente |
| Raíces Protectoras | A | T, R | 2 | 2 | 3 | Crea muros de raíces en 2 casillas vacías adyacentes (bloquean como tótems). Mantenimiento: 1⚡ por turno | Los muros no pagan mantenimiento el primer turno |
| Savia Curativa | R | R | 2 | 3 | — | Cuando el rival captura un peón o una pieza menor tuya, la pieza vuelve a la primera casilla libre de tu fila inicial | Funciona también con torres |
| **Ritual: El Bosque Marcha** | U | — | — | 10 | — | Todas tus piezas avanzan 1 casilla si está libre y tienen Corteza hasta tu próximo turno | — |

#### 🌑 Sombra (desplazamiento)

| Rasgo | Tipo | Piezas | Pts | ⚡ | CD | Efecto | Nv2 |
|---|---|---|---|---|---|---|---|
| Paso Sombrío | A | A, T, D | 2 | 2 | 3 | Este turno la pieza mueve como un Caballo y salta obstáculos, sin capturar | Puede capturar |
| Intercambio de Sombras | A | R, T | 2 | 3 | 5 | Intercambia la posición de esta pieza con otra tuya. Es el "enroque libre" | CD 3 |
| Esquiva Sombría | R | C, A | 2 | 2 | — | Cuando van a capturarla, salta a la casilla libre adyacente más alejada del atacante y la captura falla. El atacante pierde su movimiento | Se arma por 1⚡ |
| Botas de Montaraz | P | P | 1 | — | — | El peón puede avanzar 1 o 2 casillas siempre y moverse 1 en lateral sin capturar | También puede retroceder 1 |
| **Ritual: Asesinato en la Sombra** | U | — | — | 10 | — | Una pieza tuya (no la dama) aparece junto al Rey rival. No puede capturar este turno, pero crea una amenaza inmediata | — |

#### ❄️ Escarcha (control)

| Rasgo | Tipo | Piezas | Pts | ⚡ | CD | Efecto | Nv2 |
|---|---|---|---|---|---|---|---|
| Toque Helado | A | Todas | 2 | 2 | 3 | Congela 1 turno a una pieza rival adyacente (no se mueve ni usa poderes). No afecta al Rey | Congela 2 turnos |
| Runa de Escarcha | R | A, D, R | 2 | 2 | — | Runa oculta en una casilla vacía a ≤2 casillas. La primera pieza rival que entre o pase por ella se detiene y queda congelada 2 turnos (el Rey, 1). Máx. 2 runas | Radio 3 |
| Aura Gélida | P | T, D | 3 | — | — | Las piezas rivales que empiezan su movimiento adyacentes a esta solo pueden moverse 1 casilla | Radio 2 |
| Maldición Ovina | A | A, D | 3 | 4 | 5 | Una pieza rival que esta pieza ataca se convierte en Oveja 2 turnos: mueve 1 casilla, no captura y pierde sus rasgos. No afecta al Rey | 3 turnos |
| **Ritual: Invierno Eterno** | U | — | — | 10 | — | Congela 1 turno hasta 3 piezas rivales a tu elección (no el Rey) | — |

#### ✨ Arcano (manipulación del tablero)

| Rasgo | Tipo | Piezas | Pts | ⚡ | CD | Efecto | Nv2 |
|---|---|---|---|---|---|---|---|
| Portal Arcano | A | D, R | 3 | 4 | 6 | Teletransporte a cualquier casilla vacía de tu mitad del tablero | CD 4 |
| Remodelar | A | Todas | 2 | 2 | 3 | Crea o destruye un tótem en una casilla vacía a ≤2 casillas. Máx. 3 tótems propios | Radio 3 |
| Imán de Mithril | A | A, T, D | 2 | 3 | 4 | Atrae una pieza rival (no el Rey) o un doblón que esté en línea recta a ≤3 casillas hasta dejarlo adyacente a esta pieza | Radio 4 |
| Contrahechizo | R | Todas | 2 | 3 | — | Anula el próximo poder activo o Ritual del rival. El rival paga el coste y el cooldown igualmente | Te devuelve 2⚡ |
| **Ritual: Gran Transposición** | U | — | — | 10 | — | Intercambia la posición de una pieza tuya con cualquier pieza rival (los reyes no) | — |

#### 🔥 Dragón (agresión)

| Rasgo | Tipo | Piezas | Pts | ⚡ | CD | Efecto | Nv2 |
|---|---|---|---|---|---|---|---|
| Tributo del Dragón | P | Todas | 2 | — | — | Cuando esta pieza captura: +2⚡ extra y robas 1 doblón al rival | +3⚡ |
| Frenesí | A | C, A, T | 3 | 3 | 4 | Si esta pieza captura este turno, puede hacer otra captura seguida | Cuesta 2⚡ |
| Aliento de Dragón | A | T, D | 3 | 4 | 5 | Elimina un peón o una pieza menor rival en línea recta a ≤3 casillas, con el camino libre y sin moverse | También alcanza torres |
| Represalia Ígnea | R | Todas salvo R | 2 | 2 | — | Si capturan esta pieza, la atacante también muere. Si la atacante es el Rey o la Dama, queda congelada 1 turno | — |
| **Ritual: Anillo de Poder** | U | — | — | 10 | — | Una pieza tuya (no el Rey) se convierte en Dama para siempre y conserva su rasgo. Pero el Anillo llama al enemigo: el rival gana +3⚡ | — |

#### Neutrales (no cuentan para ninguna escuela)

| Rasgo | Tipo | Piezas | Pts | ⚡ | CD | Efecto |
|---|---|---|---|---|---|---|
| Ojo del Vigía | P | Todas | 1 | — | — | Ves los rasgos ocultos, las runas y las reactivas del rival a ≤2 casillas de esta pieza |
| Niebla de la Ciénaga | A | Todas | 2 | 2 | 4 | Crea una zona de ciénaga de 3×3 a ≤2 casillas durante 2 turnos |

**Rasgos de la configuración A (10):** Corteza de Ent, Capa Élfica, Paso Sombrío, Botas de Montaraz, Toque Helado, Runa de Escarcha, Imán de Mithril, Contrahechizo, Tributo del Dragón y Aliento de Dragón.

### 4.4 Combos
El juego detecta estas combinaciones y anuncia su nombre en pantalla. Es lo que le da sentido a *VoodooCombo*.

| Combo | Cómo se hace | Bonus |
|---|---|---|
| **Prisión Glacial** | Imán de Mithril arrastra una pieza rival sobre tu Runa de Escarcha | La congelación dura 3 turnos |
| **Saqueo Fantasma** | Paso Sombrío Nv2 captura con una pieza que tiene Tributo del Dragón | Roba 2 doblones |
| **Ejecución** | Aliento de Dragón contra una pieza congelada o convertida en oveja | Puede eliminar torres y damas |
| **Contraataque Arcano** | Se dispara tu Contrahechizo | Tu siguiente poder cuesta 0⚡ |
| **Cadena Vudú** | Frenesí encadena dos capturas | +3⚡ |

### 4.5 Orden de resolución cuando intentan capturar una pieza
Sin un orden fijo, las reactivas dan bugs. El servidor siempre resuelve así:

1. Contrahechizo, si el ataque viene de un poder.
2. Inmunidades: Capa Élfica.
3. Esquiva Sombría: la pieza escapa y la captura falla.
4. Corteza de Ent: la pieza sobrevive y el atacante vuelve a su casilla.
5. Captura.
6. Represalia Ígnea.
7. Savia Curativa.
8. Recompensas: energía, Tributo del Dragón y veteranía.
9. Combos y comprobación de victoria.

---

## 5. Control del ritmo

| Mecanismo | Cuándo | Efecto | Para qué |
|---|---|---|---|
| Reloj de ajedrez | Siempre | Blitz 3+2 por defecto (Bala 1+1, Rápida 5+3) | Partidas de 6-8 minutos |
| Mantenimiento | Mientras dure un efecto | Los muros cuestan 1⚡ por turno | Castiga atrincherarse |
| Límite defensivo | Siempre | Máx. 2 efectos defensivos activos (Capa, muros, Niebla) | La defensa no se acumula sin fin |
| Rituales | Desde la ronda 8, con 10⚡ | Uno por partida | Final explosivo |
| **Luna de Sangre** | Ronda 12, o antes si pasan 6 rondas sin capturas | +2⚡ por turno y tinte rojo en la pantalla | Más poderes, más acción |
| **Marea Vudú** | Aviso en la ronda 14; se cierra en las rondas 16 y 22 | El anillo exterior "se descose": el tablero pasa de 8×8 a 6×6 y luego a 4×4. Las piezas que se quedan ahí mueren, salvo el Rey, que es empujado hacia dentro | Obliga a enfrentarse |
| Triple repetición | Si se repite 3 veces la misma posición | Adelanta la Marea | Evita bucles para alargar la partida |
| Rasgos que fuerzan intercambios | Siempre | Represalia, Frenesí, Aliento y Tributo | Se intercambian piezas y la partida avanza |
| Límite de rondas | Ronda 30 | Gana quien tenga más puntos | Siempre hay un final |

**Cómo debería ir una partida típica:**

| Rondas | Qué pasa |
|---|---|
| 1-4 | Apertura: carrera por los altares y los doblones, primeros poderes de 2⚡ |
| 5-11 | Medio juego: capturas, reactivas, primeros combos |
| 8+ | Ya se pueden lanzar Rituales |
| 12 | Luna de Sangre |
| 14-16 | Aviso de Marea y tablero 6×6 |
| 22 | Tablero 4×4 |
| 30 | Fin por puntos |

**Objetivo de balance:** que el 70 % de las partidas acaben antes de la ronda 20. Se mide con las partidas guardadas (§8).

---

## 6. Qué se mantiene del diseño anterior

| Antes | Ahora |
|---|---|
| Un muñeco por jugador | Un ejército de muñecos: cada pieza es un muñeco con su forma (la torre, un golem de trapo; la dama, una sacerdotisa) |
| Capturar | "Clavar el alfiler": animación de alfiler y la pieza se descose |
| 14 cartas | Los mismos nombres pasan a ser rasgos (Paso Sombrío, Runa, Capa, Tributo, Anillo...) |
| 3 combos | 5 combos con anuncio en pantalla |
| Doblones | Objetivo alternativo, energía y veteranía |
| Reloj de ajedrez, tablero simétrico, biomas | Se mantienen igual. Los biomas cambian los tótems y el color de las casillas |
| Información oculta (runas) | Ampliada a los rasgos y las reactivas, con el mismo filtrado en el servidor |
| Red ENet, LAN, servidor dedicado, endpoint HTTP | Igual. `/results` añade el ejército y los rasgos de cada jugador |
| Personalización del muñeco | Pasa a ser la "tela del ejército": todas tus piezas comparten tela, patrón y ojos |

---

## 7. Interfaz y feedback

- **Energía:** una barra de **10 alfileres** que se van clavando. Cuando está llena brilla, avisando de que el Ritual está disponible.
- **Piezas:** cada pieza muestra el icono de su escuela, la estrella de veteranía y un sello "?" si tiene una reactiva armada.
- **Seleccionar una pieza:** se ven las casillas legales con puntos y sus poderes con su coste y cooldown. Si no tienes energía suficiente, el poder sale en gris con el motivo.
- **Hover sobre una pieza rival:** se ve lo que se sabe de ella (escuela o rasgo revelado).
- **Reactivas:** cuando se dispara una, se ve una carta que se gira y el nombre del rasgo. Así el rival entiende qué ha pasado.
- **Luna de Sangre:** tinte rojo, luna en la esquina y tambores más rápidos.
- **Marea:** las casillas que van a desaparecer parpadean con costuras 2 rondas antes. Al cerrarse, se descosen con una animación.
- **Combos:** el nombre aparece en grande, con viñeta del color de su escuela y un "¡COMBO!".
- **Historial:** en notación de ajedrez, con los poderes incluidos (por ejemplo `Cd5×e7 · Frenesí · +2⚡`).
- **Para aprender a jugar:** hay ejércitos predefinidos y un tutorial de 4 tarjetas (piezas, energía, poderes, ritmo).

---

## 8. Impacto técnico (Godot y Codex)

- **Sistema de poderes basado en datos:**
  - Cada rasgo se define como datos (tipo, piezas, puntos, ⚡, CD, parámetros) más un pequeño manejador por efecto.
  - Los efectos se enganchan a eventos: `on_turn_start`, `on_move`, `on_capture_attempt`, `on_captured`, `on_turn_end`.
  - Las reactivas son escuchas de esos eventos.
- **Orden de resolución:** el de §4.5, en una sola función. Hay que testearlo bien porque es donde aparecen los bugs.
- **Información oculta:** `state.for_seat(seat)` oculta los rasgos no revelados, las runas y qué reactiva hay armada.
- **Tests:**
  - Cada pieza y cada rasgo con al menos 2 tests.
  - Cada combo con su test.
  - Tests del orden de resolución, la Marea y la Luna de Sangre.
- **Constantes:** todos los números de este documento van en `game_config.gd`, así se puede equilibrar sin tocar la lógica.
- **Telemetría para el balance:**
  - Las partidas guardadas incluyen los ejércitos, los rasgos, la ronda final y el ganador.
  - Un script resume el % de victorias por rasgo y por escuela.
  - Os da datos reales que enseñar en la presentación.
- **Fases para Codex:** la fase 1 (núcleo) crece y conviene partirla en tres:
  - 1a: ajedrez básico y terreno.
  - 1b: energía, veteranía y ritmo.
  - 1c: poderes.

---

## 9. Decisiones pendientes

| Decisión | Opciones | Recomendación |
|---|---|---|
| Configuración | A / B / C | **B**, implementada primero como A y ampliada después |
| Victoria | Regicidio / Botín | **Botín** por defecto |
| Jaque mate o capturar al Rey | Mate / Captura | **Captura** |
| Información | Abierta / Parcial / Oculta | **Parcial** |
| Ejército | Predefinidos / Constructor / Draft | **Predefinidos + constructor** |
| Despliegue | Formación guardada / Caos / A ciegas | **Formación guardada**, con Caos como modo alternativo |
| Tamaño del tablero | 8×8 / 6×6 | **8×8** con ejércitos de unos 9 piezas (6×6 si las partidas salen largas) |
