#!/usr/bin/env bash
# Actualiza el juego en el servidor: baja lo último de GitHub, genera la versión web y el .zip de Windows,
# y reinicia el servidor del juego. Uso: sudo /opt/voodoocombo/actualizar.sh
set -euo pipefail

BASE="/opt/voodoocombo"
G="$BASE/godot/godot"
SRC="$BASE/src"
USUARIO="godotserver"

verde() { printf '\033[1;32m%s\033[0m\n' "$*"; }
aviso() { printf '\033[1;33m[AVISO] %s\033[0m\n' "$*"; }

[[ $EUID -eq 0 ]] || { echo "Ejecútalo con sudo"; exit 1; }
como() { sudo -u "$USUARIO" -H "$@"; }

verde "· Bajando lo último de GitHub"
como git -C "$SRC" pull --ff-only

verde "· Importando el proyecto (la primera vez tarda un par de minutos)"
como "$G" --headless --path "$SRC" --import >/dev/null 2>&1 || como "$G" --headless --path "$SRC" --editor --quit >/dev/null 2>&1 || true

if grep -q 'name="Web"' "$SRC/export_presets.cfg"; then
  verde "· Generando la versión web"
  rm -rf "$BASE/web-nuevo"; mkdir -p "$BASE/web-nuevo"; chown "$USUARIO:$USUARIO" "$BASE/web-nuevo"
  if como "$G" --headless --path "$SRC" --export-release "Web" "$BASE/web-nuevo/index.html" && [[ -f "$BASE/web-nuevo/index.html" ]]; then
    # se conserva la carpeta de descargas
    [[ -d "$BASE/web/descargar" ]] && cp -r "$BASE/web/descargar" "$BASE/web-nuevo/"
    rm -rf "$BASE/web-viejo"; mv "$BASE/web" "$BASE/web-viejo"; mv "$BASE/web-nuevo" "$BASE/web"
  else
    aviso "No se ha podido exportar la versión web: se queda la anterior."
  fi
else
  aviso "El proyecto todavía no tiene versión web (preset \"Web\", fase 15). Solo se actualiza el servidor."
fi

if grep -q 'name="Windows"' "$SRC/export_presets.cfg"; then
  verde "· Generando el .zip de Windows"
  rm -rf "$BASE/build"; mkdir -p "$BASE/build" "$BASE/web/descargar"; chown -R "$USUARIO:$USUARIO" "$BASE/build" "$BASE/web/descargar"
  if como "$G" --headless --path "$SRC" --export-release "Windows" "$BASE/build/VoodooCombo.exe" && [[ -f "$BASE/build/VoodooCombo.exe" ]]; then
    [[ -f "$SRC/deploy/LEEME-windows.txt" ]] && cp "$SRC/deploy/LEEME-windows.txt" "$BASE/build/LEEME.txt"
    (cd "$BASE/build" && zip -qr "$BASE/web/descargar/VoodooCombo-Windows.zip" .)
  else
    aviso "No se ha podido exportar Windows: se queda el .zip anterior."
  fi
fi
chown -R "$USUARIO:$USUARIO" "$BASE"

if ! grep -q -- '--ws' "$SRC/net/server_main.gd"; then
  aviso "El servidor del juego todavía no entiende --ws (fase 15): arrancará, pero la web no podrá conectarse aún."
fi

verde "· Reiniciando el servidor del juego"
systemctl restart voodoocombo
sleep 2
systemctl is-active --quiet voodoocombo && verde "Hecho: servidor en marcha." || aviso "El servidor no arranca: sudo journalctl -u voodoocombo -n 50"
