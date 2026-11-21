#!/bin/zsh
# instalar.sh · prepara esta carpeta en un Mac: compila las dos herramientas,
# guarda el nombre del iPad y deja los agentes de launchd listos SIN cargarlos.
# Uso: ./instalar.sh "Nombre del iPad"      (el nombre sale de Ajustes → General → Información)
set -e
HERE="${0:A:h}"
NOMBRE="${1:?Uso: ./instalar.sh \"Nombre del iPad\"}"
cd "$HERE"

swiftc -O src/espejo.swift -o espejo
swiftc -O src/vigilar_cable.swift -o vigilar_cable
chmod +x pantalla.sh tailscale/tailscale-arriba.sh
print -r -- "$NOMBRE" > ipad_name

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
for t in pantalla-ipad tailscale-arriba; do
  sed -e "s|__DIR__|$HERE|g" -e "s|__HOME__|$HOME|g" "launchd/$t.plist.template" \
    > "$HOME/Library/LaunchAgents/local.ipad-pantalla.$t.plist"
done

cat <<MSG
Listo. Falta, a mano:
  1. Poner SidecarLauncher en esta carpeta:  $HERE/SidecarLauncher  (ver README)
  2. Cargar los agentes cuando quieras:
       launchctl load ~/Library/LaunchAgents/local.ipad-pantalla.pantalla-ipad.plist
       launchctl load ~/Library/LaunchAgents/local.ipad-pantalla.tailscale-arriba.plist   # opcional
  Para quitarlos: launchctl unload <el mismo archivo> y borrar el .plist.
MSG
