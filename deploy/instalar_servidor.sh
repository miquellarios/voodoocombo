#!/usr/bin/env bash
# Instala el servidor online de VoodooCombo en una máquina Ubuntu 24.04 (Oracle Cloud u otra).
# Deja montado:
#   - el servidor del juego (Godot sin pantalla) como servicio que se reinicia solo;
#   - Caddy, que sirve la versión web por HTTPS y pasa las conexiones del juego (WebSocket) al servidor;
#   - DuckDNS actualizado (opcional).
#
# Uso (en la máquina, por SSH):
#   sudo bash instalar_servidor.sh <dominio> [token_duckdns]
#   sudo bash instalar_servidor.sh voodoocombo.duckdns.org 1234abcd-....
#
# Se puede ejecutar otra vez sin miedo: si algo ya está hecho, lo deja como está.
set -euo pipefail

DOMINIO="${1:-}"
DUCK_TOKEN="${2:-}"
GODOT_VER="4.7.2"
REPO="https://github.com/miquellarios/voodoocombo.git"
BASE="/opt/voodoocombo"
DATOS="/var/lib/voodoocombo"
USUARIO="godotserver"
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

verde() { printf '\033[1;32m%s\033[0m\n' "$*"; }
aviso() { printf '\033[1;33m[AVISO] %s\033[0m\n' "$*"; }
fallo() { printf '\033[1;31m[ERROR] %s\033[0m\n' "$*"; exit 1; }

[[ $EUID -eq 0 ]] || fallo "Ejecútalo con sudo: sudo bash instalar_servidor.sh <dominio> [token]"
[[ -n "$DOMINIO" ]] || fallo "Falta el dominio. Ejemplo: sudo bash instalar_servidor.sh voodoocombo.duckdns.org TU_TOKEN"

case "$(uname -m)" in
  aarch64|arm64) ARQ="arm64" ;;
  x86_64|amd64)  ARQ="x86_64" ;;
  *) fallo "Arquitectura no soportada: $(uname -m)" ;;
esac

verde "1/8 · Paquetes del sistema"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git unzip zip curl caddy ca-certificates

verde "2/8 · Usuario $USUARIO y carpetas"
id "$USUARIO" >/dev/null 2>&1 || useradd --system --home "$DATOS" --create-home --shell /usr/sbin/nologin "$USUARIO"
mkdir -p "$BASE/godot" "$BASE/web" "$BASE/build" "$DATOS"

verde "3/8 · Godot $GODOT_VER ($ARQ)"
if [[ ! -x "$BASE/godot/godot" ]]; then
  tmp="$(mktemp -d)"
  curl -fL --retry 3 -o "$tmp/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/Godot_v${GODOT_VER}-stable_linux.${ARQ}.zip"
  unzip -q "$tmp/godot.zip" -d "$tmp"
  mv "$tmp/Godot_v${GODOT_VER}-stable_linux.${ARQ}" "$BASE/godot/godot"
  chmod +x "$BASE/godot/godot"
  rm -rf "$tmp"
fi
"$BASE/godot/godot" --headless --version || fallo "Godot no arranca en esta máquina"

verde "4/8 · Plantillas de exportación (versión web y Windows)"
PLANTILLAS="$DATOS/.local/share/godot/export_templates/${GODOT_VER}.stable"
if [[ ! -f "$PLANTILLAS/web_nothreads_release.zip" && ! -f "$PLANTILLAS/web_release.zip" ]]; then
  tmp="$(mktemp -d)"
  curl -fL --retry 3 -o "$tmp/plantillas.tpz" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/Godot_v${GODOT_VER}-stable_export_templates.tpz"
  unzip -q "$tmp/plantillas.tpz" -d "$tmp"
  mkdir -p "$PLANTILLAS"
  cp -r "$tmp/templates/." "$PLANTILLAS/"
  rm -rf "$tmp"
fi

verde "5/8 · Código del juego"
if [[ -d "$BASE/src/.git" ]]; then
  git -C "$BASE/src" pull --ff-only
else
  git clone --depth 1 "$REPO" "$BASE/src"
fi
cp "$AQUI/actualizar.sh" "$BASE/actualizar.sh" 2>/dev/null || cp "$BASE/src/deploy/actualizar.sh" "$BASE/actualizar.sh"
chmod +x "$BASE/actualizar.sh"
chown -R "$USUARIO:$USUARIO" "$BASE" "$DATOS"

verde "6/8 · Cortafuegos de la máquina (puertos 80 y 443)"
# Las imágenes de Ubuntu de Oracle traen iptables que solo dejan pasar SSH.
if ! iptables -C INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null; then
  iptables -I INPUT 1 -p tcp -m multiport --dports 80,443 -j ACCEPT
fi
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save
else
  aviso "No está netfilter-persistent: la regla del cortafuegos se pierde al reiniciar. Vuelve a lanzar este script después de un reinicio."
fi

verde "7/8 · DuckDNS, servicio del juego y Caddy"
if [[ -n "$DUCK_TOKEN" ]]; then
  SUB="${DOMINIO%%.duckdns.org}"
  cat > /etc/cron.d/voodoocombo-duckdns <<EOF
*/5 * * * * root curl -fsS "https://www.duckdns.org/update?domains=${SUB}&token=${DUCK_TOKEN}&ip=" -o /dev/null
EOF
  chmod 600 /etc/cron.d/voodoocombo-duckdns
  resp="$(curl -fsS "https://www.duckdns.org/update?domains=${SUB}&token=${DUCK_TOKEN}&ip=" || true)"
  [[ "$resp" == "OK" ]] || aviso "DuckDNS no ha contestado OK (contestó: '$resp'). Revisa el subdominio y el token."
fi

cp "$BASE/src/deploy/voodoocombo.service" /etc/systemd/system/voodoocombo.service
sed "s/__DOMINIO__/${DOMINIO}/g" "$BASE/src/deploy/Caddyfile.plantilla" > /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile || fallo "El Caddyfile no es válido"
systemctl daemon-reload
systemctl enable voodoocombo caddy

verde "8/8 · Versión web, ejecutable y arranque"
"$BASE/actualizar.sh"
systemctl restart caddy

# ---------------------------------------------------------------- comprobaciones finales
IP_PUBLICA="$(curl -fsS https://api.ipify.org || echo '?')"
IP_DOMINIO="$(getent ahostsv4 "$DOMINIO" | awk 'NR==1{print $1}' || true)"
echo
if [[ "$IP_PUBLICA" != "$IP_DOMINIO" ]]; then
  aviso "El dominio $DOMINIO apunta a '${IP_DOMINIO:-nada}' pero esta máquina es $IP_PUBLICA."
  aviso "Pon la IP $IP_PUBLICA en DuckDNS y espera 1-2 minutos. Caddy pedirá el certificado solo."
fi
sleep 3
if systemctl is-active --quiet voodoocombo; then verde "Servidor del juego: EN MARCHA"; else aviso "El servidor del juego no arranca: sudo journalctl -u voodoocombo -n 50"; fi
if systemctl is-active --quiet caddy; then verde "Caddy (web y HTTPS): EN MARCHA"; else aviso "Caddy no arranca: sudo journalctl -u caddy -n 50"; fi
echo
verde "Listo. Abre en el navegador:  https://${DOMINIO}"
echo   "Estado del servidor:           https://${DOMINIO}/estado"
echo   "Para actualizar el juego:      sudo ${BASE}/actualizar.sh"
echo   "Ver lo que pasa en directo:    sudo journalctl -u voodoocombo -f"
