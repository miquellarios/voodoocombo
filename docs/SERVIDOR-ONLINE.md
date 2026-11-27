# Montar el servidor online de VoodooCombo (gratis, paso a paso)

**Para Miquel y Joel.** Se hace **una sola vez** y se tarda unos 45 minutos.

**Qué consigues:** una dirección como `https://voodoocombo.duckdns.org`.
- Cualquiera la abre en el navegador y juega, sin instalar nada.
- El `.exe` se conecta al mismo servidor.
- Para jugar con un amigo, el anfitrión pulsa **INVITAR** y le manda el enlace por WhatsApp. El amigo lo abre y ya está en la sala.

**Qué necesitas:**
- un ordenador con Windows 10 u 11;
- un móvil;
- una tarjeta para verificar la cuenta de Oracle. **No cobra nada** mientras no pulses "Upgrade".

> El juego necesita la **fase 15** hecha por Codex para que la web pueda conectarse.
> Los pasos 1 a 5 se pueden hacer ya: el servidor queda preparado y, cuando Codex termine la fase 15, solo hay que ejecutar `sudo /opt/voodoocombo/actualizar.sh` (paso 8).

---

## 1. Crear la cuenta de Oracle Cloud (10 min)

1. Entra en <https://www.oracle.com/cloud/free/> y pulsa **Start for free**.
2. Rellena tus datos y verifica el correo y el móvil.
3. **MUY IMPORTANTE:** en **Home Region** elige **Spain Central (Madrid)**. Las máquinas gratis solo se pueden crear en esa región y **no se puede cambiar después**.
4. Pon la tarjeta: hacen una comprobación de 1 € o menos que se devuelve.
5. Espera al correo de "Your account is ready" (de 5 minutos a un par de horas).

## 2. Crear la máquina (10 min)

1. Entra en <https://cloud.oracle.com>. Menú ☰ → **Compute** → **Instances** → **Create instance**.
2. **Name:** `voodoocombo`.
3. **Image and shape** → **Edit**:
   - **Image:** **Canonical Ubuntu 24.04** (pulsa *Change image* si sale otra).
   - **Shape:** **Ampere** → **VM.Standard.A1.Flex**, con **1 OCPU** y **6 GB** de memoria. Tiene que poner la etiqueta *Always Free-eligible*.
   - Si al crear sale **"Out of capacity"**, vuelve aquí y elige **Specialty and previous generation** → **VM.Standard.E2.1.Micro**. También es gratis y da de sobra para el juego.
4. **Networking:** deja **Create new virtual cloud network** y **Create new public subnet**. Comprueba que está marcado **Assign a public IPv4 address**.
5. **Add SSH keys:** **Generate a key pair for me** → pulsa **Download private key**.
   - Guarda el archivo (`ssh-key-….key`) en `C:\voodoocombo\clave.key`. **No lo subas a GitHub ni lo compartas.**
6. Pulsa **Create**. Cuando el cuadro se ponga verde (**Running**), apunta la **Public IP address** (por ejemplo `152.70.10.20`).

## 3. Abrir los puertos web en Oracle (3 min)

1. En la página de la máquina: **Primary VNIC** → pulsa el nombre de la **Subnet** → **Security Lists** → **Default Security List…**
2. **Add Ingress Rules**:
   - Source CIDR: `0.0.0.0/0`
   - IP Protocol: `TCP`
   - Destination Port Range: `80,443`
3. **Add Ingress Rules** para guardar.

## 4. Crear el dominio gratis en DuckDNS (3 min)

1. Entra en <https://www.duckdns.org> y accede con GitHub o Google.
2. En **sub domain** escribe `voodoocombo` (o el que esté libre) → **add domain**.
3. En **current ip** pon la **IP pública** de la máquina (paso 2.6) → **update ip**.
4. Apunta el **token** que sale arriba: lo necesitas en el paso 6.

Tu dirección será `https://voodoocombo.duckdns.org` (o la que hayas elegido).

## 5. Entrar en la máquina desde Windows (5 min)

1. Abre **PowerShell** (botón Inicio → escribe "PowerShell").
2. La primera vez, dale permisos a la clave para que SSH no se queje:
   ```powershell
   icacls C:\voodoocombo\clave.key /inheritance:r /grant:r "$($env:USERNAME):(R)"
   ```
3. Conéctate, cambiando la IP por la tuya:
   ```powershell
   ssh -i C:\voodoocombo\clave.key ubuntu@152.70.10.20
   ```
   - Si pregunta "Are you sure you want to continue connecting?", escribe `yes`.
   - Cuando veas algo como `ubuntu@voodoocombo:~$`, ya estás dentro.

## 6. Instalar todo con un solo comando (10-15 min)

Dentro de la máquina, copia y pega esto, cambiando el dominio y el token por los tuyos:

```bash
curl -fsSL https://raw.githubusercontent.com/miquellarios/voodoocombo/main/deploy/instalar_servidor.sh -o instalar.sh
sudo bash instalar.sh voodoocombo.duckdns.org TU_TOKEN_DE_DUCKDNS
```

**El script lo hace todo solo:**
- instala Godot, el servidor del juego y Caddy (la web con HTTPS);
- abre el cortafuegos de la máquina;
- configura DuckDNS;
- genera la versión web y el `.zip` de Windows;
- deja el servidor como servicio, que **se reinicia solo** si se cae o si se reinicia la máquina.

Al final tiene que salir:

```
Servidor del juego: EN MARCHA
Caddy (web y HTTPS): EN MARCHA
Listo. Abre en el navegador:  https://voodoocombo.duckdns.org
```

## 7. Comprobar

- Abre `https://voodoocombo.duckdns.org` en el navegador: tiene que cargar el juego. Esto funciona cuando Codex ha hecho la fase 15.
- Abre `https://voodoocombo.duckdns.org/estado`: tiene que salir un texto con `rooms`.
- **Prueba real:** cada uno en su casa abre la web; uno pulsa **JUGAR ONLINE** → **INVITAR** y le manda el enlace al otro.

## 8. Actualizar el juego cuando Codex suba cambios

Conéctate como en el paso 5 y ejecuta:

```bash
sudo /opt/voodoocombo/actualizar.sh
```

Baja lo último de GitHub, regenera la web y el `.exe`, y reinicia el servidor. Las partidas que estén en marcha en ese momento se cortan, así que hazlo cuando no esté jugando nadie.

---

## Si algo falla

| Qué pasa | Qué hacer |
|---|---|
| "Out of capacity" al crear la máquina | Usa **VM.Standard.E2.1.Micro** (paso 2.3) o prueba otra vez más tarde |
| `ssh` dice "UNPROTECTED PRIVATE KEY FILE" o "Permission denied" | Repite el `icacls` del paso 5.2 y comprueba que el usuario es `ubuntu` |
| La web no carga o el navegador dice "no es seguro" | El dominio no apunta a la máquina o los puertos 80/443 están cerrados. Revisa los pasos 3 y 4, espera 2 minutos y ejecuta `sudo systemctl restart caddy` |
| El juego dice "Servidor en mantenimiento" | `sudo systemctl status voodoocombo` y `sudo journalctl -u voodoocombo -n 50`. Mándale a Claude lo que salga |
| Quieres ver lo que pasa en directo | `sudo journalctl -u voodoocombo -f` (salir con Ctrl+C) |
| Oracle ha borrado la máquina por estar "inactiva" | Puede pasar con las máquinas gratis que casi no se usan. Crea otra (pasos 2-6): en 20 minutos vuelve a estar |

**Coste: 0 €.**
- No pulses nunca **Upgrade to Pay As You Go**.
- Usa solo cosas marcadas como *Always Free*.
- La clave SSH y el token de DuckDNS **no se suben a GitHub**.
