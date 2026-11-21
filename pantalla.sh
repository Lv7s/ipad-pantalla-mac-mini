#!/bin/zsh
# pantalla.sh · iPad como pantalla principal de un Mac mini sin monitor, por Sidecar.
# Uso: pantalla.sh conectar [cable]   |   soltar   |   ajustar
# Probado en macOS 27.0 y 27.2.1. Registro: ~/Library/Logs/pantalla-ipad.log
#
# El nombre del iPad sale de la variable IPAD_NAME o, si no existe, del archivo
# «ipad_name» junto a este script (lo escribe instalar.sh).

HERE="${0:A:h}"
IPAD="${IPAD_NAME:-$(cat "$HERE/ipad_name" 2>/dev/null)}"
if [[ -z "$IPAD" ]]; then print -u2 "Falta el nombre del iPad: define IPAD_NAME o ejecuta instalar.sh"; exit 2; fi
VIRTUAL="Pantalla iPad"
SL="${SL:-$HERE/SidecarLauncher}"
BD="/opt/homebrew/bin/betterdisplaycli"
LOG="$HOME/Library/Logs/pantalla-ipad.log"
LOCK="/tmp/pantalla-ipad.lock"
INTENTOS=12      # 12 intentos x 10 s = 2 minutos como máximo
ESPERA=10

log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

# Entrada desde la llave SSH del iPad (authorized_keys con command=): solo se
# aceptan las órdenes «conectar» y «soltar»; cualquier otra cosa se rechaza.
if [[ "$1" == "ssh" ]]; then
  case "$SSH_ORIGINAL_COMMAND" in
    conectar)
      # Se responde al iPad al instante y se conecta 4 s después, con el atajo
      # ya terminado: si Sidecar entra mientras Atajos sigue ejecutándose en el
      # iPad, la sesión se cae («El dispositivo se desconectó», 20-11-2026).
      log "orden por SSH desde el iPad: conectar (diferida 4 s)"
      nohup /bin/zsh -c "sleep 4; '$0' conectar" >/dev/null 2>&1 &!
      print "Conectando la pantalla en unos segundos…"
      exit 0 ;;
    soltar) log "orden por SSH desde el iPad: soltar"
            exec "$0" soltar ;;
    *) log "orden SSH rechazada: $SSH_ORIGINAL_COMMAND"
       print "Solo se permite: conectar | soltar"; exit 1 ;;
  esac
fi

# Un solo proceso a la vez.
if ! mkdir "$LOCK" 2>/dev/null; then
  [[ "$1" == "ajustar" ]] && exit 0   # el que tiene el candado ya ajusta al terminar
  log "ya hay otro intento en curso; salgo"
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

ya_conectado() { system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Sidecar"; }

# Nombres de las pantallas activas según macOS, una por línea.
pantallas() {
  system_profiler SPDisplaysDataType 2>/dev/null |
    awk '/Displays:/{f=1;next} f && /^        [^ ].*:$/{sub(/^ +/,"");sub(/:$/,"");print}'
}

# Nombre en BetterDisplay del primer monitor real conectado (ni el iPad ni la virtual).
monitor_bd() {
  "$BD" get -identifiers 2>/dev/null | python3 -I -c '
import json, sys
ipad = sys.argv[1]
for x in json.loads("[" + sys.stdin.read() + "]"):
    if x.get("deviceType") == "Display" and x.get("name") != ipad:
        print(x["name"]); break' "$IPAD"
}
hay_monitor() { (( $(pantallas | grep -v -x -e "$VIRTUAL" -e "Sidecar Display" | wc -l) > 0 )); }

# Duplica la pantalla $1 (nombre en BetterDisplay) en el iPad con `espejo`
# (CoreGraphics, igual que «Duplicar» en Ajustes). «betterdisplaycli -mirror»
# falló con la virtual como origen (14:39, 20-11-2026).
ESPEJO="$HERE/espejo"
display_id() {
  "$BD" get -identifiers 2>/dev/null | python3 -I -c '
import json, sys
for x in json.loads("[" + sys.stdin.read() + "]"):
    if x.get("name") == sys.argv[1] and x.get("displayID"):
        print(x["displayID"]); break' "$1"
}
duplicar_en_ipad() {
  local origen="$1" o c
  for j in {1..5}; do
    o=$(display_id "$origen"); c=$("$ESPEJO" ipad)
    if [[ -n "$o" && -n "$c" ]]; then
      "$ESPEJO" "$o" "$c" >/dev/null 2>&1
      sleep 2
      if "$ESPEJO" | awk -v c="$c" -v o="$o" '$1==c && $4=="espejo_de="o {f=1} END{exit !f}'; then
        log "duplicando: $origen → $IPAD"; return 0
      fi
    fi
    sleep 2
  done
  log "no pude duplicar $origen en el iPad (origen=$o copia=$c; pantallas: $("$ESPEJO" | tr '\t\n' ' ;'))"
}

# Regla de la pantalla virtual (corregida 20-11-2026 tras el reinicio):
# - Con un monitor real: virtual APAGADA (si no, queda una pantalla invisible).
# - Sin monitor real: virtual ENCENDIDA siempre, también con el iPad conectado.
#   Sidecar no se sostiene como única pantalla del Mac: al apagar la virtual
#   con solo el iPad, Sidecar se cayó a los ~4 s en las 4 pruebas de las 14:31-14:33.
#   Para que la virtual no sea una zona invisible, el iPad la duplica.
ajustar() {
  local estado=off
  pantallas | grep -q -x "$VIRTUAL" && estado=on
  if hay_monitor; then
    if [[ "$estado" == on ]]; then
      "$BD" set -name="$VIRTUAL" -connected=off >/dev/null 2>&1
      log "virtual apagada (hay monitor real: $(pantallas | grep -v -x -e "$VIRTUAL" -e "Sidecar Display" | paste -sd, -))"
    fi
  else
    if [[ "$estado" != on ]]; then
      "$BD" set -name="$VIRTUAL" -connected=on >/dev/null 2>&1
      log "virtual encendida (sin monitor real)"
      sleep 2
    fi
    if ya_conectado; then
      local v=$(display_id "$VIRTUAL") c=$("$ESPEJO" ipad)
      "$ESPEJO" | awk -v c="$c" -v v="$v" '$1==c && $4=="espejo_de="v {f=1} END{exit !f}' ||
        duplicar_en_ipad "$VIRTUAL"
    fi
  fi
}

case "$1" in
  conectar)
    if ya_conectado; then log "Sidecar ya estaba conectado"; ajustar; exit 0; fi
    # Decisión de diseño: con un monitor real, enchufar el cable no
    # conecta el iPad; para eso está el atajo «Pantalla Mac».
    if [[ "$2" == "cable" ]] && hay_monitor; then
      log "hay un monitor real ($(pantallas | paste -sd, -)): no conecto por cable (usa el atajo)"; exit 0
    fi
    # Sin ninguna pantalla macOS no arranca Sidecar: se enciende la virtual primero.
    "$BD" set -name="$VIRTUAL" -connected=on >/dev/null 2>&1
    sleep 2
    opcion=""
    [[ "$2" == "cable" ]] && opcion="-wired"
    for i in {1..$INTENTOS}; do
      salida=$("$SL" connect "$IPAD" $opcion 2>&1)
      if [[ "$salida" == *connected* ]]; then
        log "conectado (${2:-wifi}) en el intento $i"
        sleep 3
        if ! ya_conectado; then
          log "Sidecar se cayó justo después de conectar"
          ajustar
        elif hay_monitor; then
          # Con monitor real: se apaga la virtual y el iPad duplica el monitor
          # (decisión de diseño). La virtual se apaga antes de duplicar.
          ajustar
          sleep 3
          duplicar_en_ipad "$(monitor_bd)"
        else
          # Sin monitor real: la virtual sigue encendida y el iPad la duplica.
          ajustar
        fi
        exit 0
      fi
      log "intento $i sin éxito: ${salida//$'\n'/ }"
      sleep $ESPERA
    done
    log "me rindo tras $INTENTOS intentos (¿iPad bloqueado o lejos?)"
    ajustar
    exit 1
    ;;
  soltar)
    salida=$("$SL" disconnect "$IPAD" 2>&1)
    log "soltar: ${salida//$'\n'/ }"
    sleep 2
    ajustar
    ;;
  ajustar)
    ajustar
    ;;
  *)
    print "Uso: $0 conectar [cable] | soltar | ajustar"
    exit 1
    ;;
esac
