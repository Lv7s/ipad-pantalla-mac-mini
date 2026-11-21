#!/bin/zsh
# tailscale-arriba.sh · si Tailscale está parado, lo conecta (sin sudo).
# Lo lanza launchd (local.ipad-pantalla.tailscale) al iniciar sesión y cada 5 minutos.
# Motivo: tras el reinicio del 20-11-2026 la app abrió pero la VPN quedó
# «stopped», y sin Tailscale no se puede entrar al Mac mini por SSH desde fuera.
T="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
LOG="$HOME/Library/Logs/tailscale-arriba.log"
log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

for i in {1..12}; do                      # hasta 2 minutos tras el arranque
  estado=$("$T" status 2>&1 | head -1)
  if [[ "$estado" == *"Tailscale is stopped"* ]]; then
    "$T" up >/dev/null 2>&1
    sleep 5
    if "$T" status >/dev/null 2>&1; then log "estaba parado; conectado con tailscale up"; exit 0; fi
  elif "$T" status >/dev/null 2>&1; then
    exit 0                                # ya conectado: no hace nada ni escribe
  fi
  sleep 10                                # la app aún no responde: esperar
done
log "no pude conectar Tailscale tras 2 minutos: $estado"
exit 1
