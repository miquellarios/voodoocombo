#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
exec ./build/VoodooCombo-server.x86_64 --headless -- --server --port 7777
