#!/usr/bin/env bash
# Actualiza el juego en el servidor: baja lo último de GitHub, genera la versión web y el .zip de Windows,
# y reinicia el servidor del juego.
#
#   sudo /opt/voodoocombo/actualizar.sh          -> actualiza ya
#   sudo /opt/voodoocombo/actualizar.sh --auto   -> solo si hay cambios en GitHub y no hay nadie jugando
#                                                    (lo lanza solo un temporizador cada 10 minutos)
set -euo pipefail

BASE="${VC_BASE:-/opt/voodoocombo}"
USUARIO="${VC_USUARIO:-godotserver}"
G="$BASE/godot/godot"
SRC="$BASE/src"
AUTO=0; [[ "${1:-}" == "--auto" ]] && AUTO=1

verde() { printf '\033[1;32m%s\033[0m\n' "$*"; }
aviso() { printf '\033[1;33m[AVISO] %s\033[0m\n' "$*"; }
reiniciar() { if command -v systemctl >/dev/null 2>&1 && [[ -z "${VC_SIN_SYSTEMD:-}" ]]; then systemctl "$@"; else echo "(systemctl $*)"; fi; }

[[ $EUID -eq 0 ]] || { echo "Ejecútalo con sudo"; exit 1; }
como() { if [[ "$USUARIO" == "root" ]]; then "$@"; else sudo -u "$USUARIO" -H "$@"; fi; }

# ---------------------------------------------------------------- ¿hay algo nuevo?
como git -C "$SRC" fetch --depth 1 origin main -q
LOCAL="$(como git -C "$SRC" rev-parse HEAD)"
REMOTO="$(como git -C "$SRC" rev-parse FETCH_HEAD)"
if [[ $AUTO -eq 1 ]]; then
  if [[ "$LOCAL" == "$REMOTO" && -f "$BASE/web/index.html" ]]; then exit 0; fi
  # no se actualiza con gente dentro: se reintenta en el siguiente aviso del temporizador
  JUGANDO="$( { curl -fsS --max-time 3 http://127.0.0.1:8080/status 2>/dev/null || true; } | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(sum(len(r.get("players", [])) for r in d.get("rooms", [])))
except Exception:
    print(0)')"
  if [[ "${JUGANDO:-0}" != "0" ]]; then echo "Hay $JUGANDO jugadores dentro: se actualizará más tarde."; exit 0; fi
  verde "Cambios nuevos en GitHub ($LOCAL -> $REMOTO): actualizando"
fi

verde "· Bajando lo último de GitHub"
como git -C "$SRC" reset --hard -q FETCH_HEAD
como git -C "$SRC" clean -fdq -e .godot

verde "· Importando el proyecto (la primera vez tarda unos minutos)"
como "$G" --headless --path "$SRC" --import >/dev/null 2>&1 || true

mkdir -p "$BASE/web"
if grep -q 'name="Web"' "$SRC/export_presets.cfg"; then
  verde "· Generando la versión web"
  rm -rf "$BASE/web-nuevo"; mkdir -p "$BASE/web-nuevo"; chown "$USUARIO:$USUARIO" "$BASE/web-nuevo"
  if como "$G" --headless --path "$SRC" --export-release "Web" "$BASE/web-nuevo/index.html" >/dev/null 2>&1 && [[ -f "$BASE/web-nuevo/index.html" ]]; then
    [[ -d "$BASE/web/descargar" ]] && cp -r "$BASE/web/descargar" "$BASE/web-nuevo/"
    rm -rf "$BASE/web-viejo"; mv "$BASE/web" "$BASE/web-viejo"; mv "$BASE/web-nuevo" "$BASE/web"
  else
    aviso "No se ha podido exportar la versión web: se queda la anterior."
  fi
else
  aviso "El proyecto todavía no tiene versión web (preset \"Web\", fase 15)."
  if [[ ! -f "$BASE/web/index.html" ]]; then
    cp "$SRC/deploy/proximamente.html" "$BASE/web/index.html"
  fi
fi

if grep -q 'name="Windows"' "$SRC/export_presets.cfg"; then
  verde "· Generando el .zip de Windows"
  rm -rf "$BASE/build"; mkdir -p "$BASE/build" "$BASE/web/descargar"; chown -R "$USUARIO:$USUARIO" "$BASE/build" "$BASE/web"
  if como "$G" --headless --path "$SRC" --export-release "Windows" "$BASE/build/VoodooCombo.exe" >/dev/null 2>&1 && [[ -f "$BASE/build/VoodooCombo.exe" ]]; then
    [[ -f "$SRC/deploy/LEEME-windows.txt" ]] && cp "$SRC/deploy/LEEME-windows.txt" "$BASE/build/LEEME.txt"
    rm -f "$BASE/web/descargar/VoodooCombo-Windows.zip"
    (cd "$BASE/build" && zip -qr "$BASE/web/descargar/VoodooCombo-Windows.zip" .)
  else
    aviso "No se ha podido exportar Windows: se queda el .zip anterior."
  fi
fi
chown -R "$USUARIO:$USUARIO" "$BASE"

if ! grep -q -- '--ws' "$SRC/net/server_main.gd"; then
  aviso "El servidor del juego todavía no entiende --ws (fase 15): la web no podrá conectarse aún."
fi

verde "· Reiniciando el servidor del juego"
reiniciar restart voodoocombo
verde "Hecho: versión $(como git -C "$SRC" log -1 --format='%h %s' | cut -c1-70)"
