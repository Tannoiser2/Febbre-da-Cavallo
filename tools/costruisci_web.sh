#!/bin/bash
# Esporta la TV (Godot web) in build/web e ci copia accanto la pagina dei telefoni.
# Uso: tools/costruisci_web.sh [comando godot]
set -e
cd "$(dirname "$0")/.."
GODOT=${1:-godot}
rm -rf build/web
mkdir -p build/web
$GODOT --headless --path . --import >/dev/null 2>&1 || true
$GODOT --headless --path . --export-release "Web" build/web/index.html
test -f build/web/index.pck
cp -r web/telefono.html web/js web/css web/font web/img build/web/
touch build/web/.nojekyll
echo "Pronto in build/web"
