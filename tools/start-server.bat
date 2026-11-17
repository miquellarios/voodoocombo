@echo off
cd /d "%~dp0.."
"build\VoodooCombo-0.1.exe" --headless -- --server --port 7777
