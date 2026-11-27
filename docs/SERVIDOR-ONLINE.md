# Montar el servidor online de VoodooCombo (gratis y sin tocar comandos)

**Para Miquel.** Se hace **una sola vez**. Son unos **30 minutos de clics** más 20 minutos de esperar.

**Qué consigues:** una dirección como `https://voodoocombo.duckdns.org`.
- **Hasta que Codex termine la fase 15:** una página que dice que el servidor está en marcha, con un botón para **descargar el juego para Windows**.
- **Con la fase 15:** el juego en el navegador, con CREAR SALA → INVITAR → el amigo abre el enlace y entra en tu sala.

**No hace falta entrar en la máquina ni escribir comandos.**
- La máquina se instala sola al crearla.
- **Se actualiza sola:** cada 10 minutos mira GitHub y, si Codex ha subido algo y no hay nadie jugando, se pone al día.

**Qué necesitas:**
- un móvil;
- una tarjeta, solo para que Oracle verifique que eres una persona. **No cobra nada** mientras no pulses "Upgrade".

---

## Paso 1 · Dominio gratis en DuckDNS (3 min)

1. Entra en <https://www.duckdns.org> y pulsa **Sign in with GitHub** (o Google).
2. En **sub domain** escribe `voodoocombo` y pulsa **add domain**. Si está cogido, prueba `voodoocombo-dam` o similar.
3. **Copia el token** (la línea larga de arriba, `token: xxxxxxxx-xxxx-…`) y guárdalo en un bloc de notas.
4. La IP déjala como esté: la máquina la pone sola.

Tu dirección será `https://voodoocombo.duckdns.org`, o la que hayas elegido.

## Paso 2 · Cuenta de Oracle Cloud (10 min y esperar el correo)

1. Entra en <https://www.oracle.com/cloud/free/> → **Start for free**.
2. Rellena tus datos y verifica el correo y el móvil.
3. ⚠️ **Home Region: elige `Spain Central (Madrid)`.** Las máquinas gratis solo se pueden crear ahí y **no se puede cambiar después**.
4. Pon la tarjeta (hacen una comprobación de céntimos que se devuelve) y espera el correo "Your account is ready".

## Paso 3 · Crear la máquina que se instala sola (10 min)

1. Entra en <https://cloud.oracle.com>. Menú ☰ → **Compute** → **Instances** → **Create instance**.
2. **Name:** `voodoocombo`.
3. **Image and shape** → **Edit**:
   - **Image** → **Change image** → **Ubuntu** → **Canonical Ubuntu 24.04** → **Select image**.
   - **Shape** → **Change shape** → **Ampere** → **VM.Standard.A1.Flex** → **1 OCPU** y **6 GB** → **Select shape**. Tiene que poner *Always Free-eligible*.
4. **Networking:** déjalo como viene (*Create new virtual cloud network*, *public subnet*, *Assign a public IPv4 address* marcado).
5. **Add SSH keys:** **Generate a key pair for me** → **Download private key**. Guárdala por si un día hace falta; **no la subas a GitHub**.
6. Abajo del todo: **Show advanced options** → pestaña **Management** → **Initialization script** → **Paste cloud-init script**. Pega esto, **cambiando las dos cosas en MAYÚSCULAS** por tu dominio y tu token de DuckDNS:

   ```bash
   #!/bin/bash
   curl -fsSL https://raw.githubusercontent.com/miquellarios/voodoocombo/main/deploy/instalar_servidor.sh -o /root/instalar.sh
   bash /root/instalar.sh TUSUBDOMINIO.duckdns.org TU_TOKEN_DE_DUCKDNS
   ```

   Ejemplo: `bash /root/instalar.sh voodoocombo.duckdns.org 1a2b3c4d-1111-2222-3333-abcdefabcdef`

7. Pulsa **Create**.
   - Si sale **"Out of host capacity"**, vuelve al punto 3 y en Shape elige **Specialty and previous generation** → **VM.Standard.E2.1.Micro**. También es gratis; la instalación tardará un poco más.

## Paso 4 · Abrir la puerta de la web (3 min)

Hazlo nada más crear la máquina:

1. En la página de la máquina, baja a **Primary VNIC** → pulsa el enlace de la **Subnet**.
2. **Security Lists** → **Default Security List for …** → **Add Ingress Rules**.
3. Rellena y pulsa **Add Ingress Rules**:
   - **Source CIDR:** `0.0.0.0/0`
   - **IP Protocol:** `TCP`
   - **Destination Port Range:** `80,443`

## Paso 5 · Esperar y comprobar (20 min)

- La máquina se instala sola. Espera **20 minutos**; con la máquina pequeña E2.1.Micro, 30.
- Abre `https://TUSUBDOMINIO.duckdns.org`:
  - **Hasta la fase 15:** sale la página "El servidor está en marcha" con **Descargar para Windows**. ✅ Ya está todo montado.
  - **Con la fase 15:** sale el juego.
- `https://TUSUBDOMINIO.duckdns.org/estado` enseña las salas abiertas.

**Y ya está.** Cuando Codex suba la fase 15 a GitHub, en 10 minutos el servidor se actualiza solo y la dirección pasa a ser el juego.

---

## Si algo no va

| Qué ves | Qué hacer |
|---|---|
| A los 30 min la página no carga | Comprueba el paso 4 (puertos 80 y 443). En DuckDNS, mira que la IP del subdominio sea la *Public IP address* de la máquina. Si no, ponla a mano y pulsa *update ip*. Espera 5 minutos |
| El navegador dice "no es seguro" | El certificado aún no está: pasa si el paso 4 se hizo tarde. Espera 5 minutos y recarga |
| "Out of host capacity" | Usa **VM.Standard.E2.1.Micro** (paso 3.7) o prueba más tarde |
| Quieres ver qué ha pasado en la instalación | Entra por SSH (abajo) y ejecuta `sudo cat /var/log/voodoocombo-instalacion.log`. Mándale a Claude lo que salga |
| Quieres forzar una actualización ya | Por SSH: `sudo /opt/voodoocombo/actualizar.sh` |
| Oracle ha borrado la máquina por "inactiva" | Puede pasar con las máquinas gratis que casi no se usan. Repite los pasos 3 y 4: en 20 minutos vuelve a estar. El dominio y el token de DuckDNS valen los mismos |

### Entrar por SSH (solo si hace falta)

En PowerShell, con la clave del paso 3.5 en `C:\voodoocombo\clave.key` y la *Public IP address* de la máquina:

```powershell
icacls C:\voodoocombo\clave.key /inheritance:r /grant:r "$($env:USERNAME):(R)"
ssh -i C:\voodoocombo\clave.key ubuntu@LA_IP_DE_LA_MAQUINA
```

**Comandos útiles dentro:**
- `sudo journalctl -u voodoocombo -f`: qué pasa en el servidor del juego (salir con Ctrl+C);
- `sudo systemctl status voodoocombo caddy`: si están en marcha;
- `sudo /opt/voodoocombo/actualizar.sh`: actualizar ya.

## Coste: 0 €

- No pulses nunca **Upgrade to Pay As You Go**.
- Usa solo cosas marcadas *Always Free*.
- El token de DuckDNS y la clave SSH **no se suben a GitHub ni se comparten**.

---

### Qué instala el script (para la documentación del proyecto)

| Pieza | Para qué |
|---|---|
| **Godot 4.7.2** sin pantalla | El servidor del juego, autoritativo: decide doblones, golpes y ganador. Corre como servicio `voodoocombo` y se reinicia solo |
| **Caddy** | Web con HTTPS: pide y renueva el certificado de Let's Encrypt solo. Sirve la versión web y pasa la conexión del juego `wss://…/ws` al servidor |
| **DuckDNS** | Dominio gratis que apunta a la máquina. Se actualiza cada 5 minutos |
| **Temporizador `voodoocombo-actualizar`** | Cada 10 minutos mira GitHub. Si hay cambios y nadie jugando, regenera la web y el `.exe` y reinicia el servidor |
| **Cortafuegos y swap** | Abre los puertos 80 y 443 dentro de la máquina, y añade 2 GB de swap si tiene poca memoria |

Los archivos están en `deploy/` del repositorio.
