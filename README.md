# ipad-pantalla-mac-mini

Usa un iPad como **única pantalla** de un Mac mini sin monitor, con Sidecar, y entra al Mac por SSH o RustDesk.
*English: scripts to use an iPad as the only display of a headless Mac mini via Sidecar, plus SSH/RustDesk notes. Spanish docs; unofficial, built on a private Apple API.*

Probado en un Mac mini con macOS 27.0 y 27.2.1 y un iPad mini 5. **No está probado en otros equipos.**

## Qué hace

- **Con cable:** al enchufar el iPad por USB, la pantalla aparece sola (si no hay un monitor real conectado).
- **Sin cable:** un atajo de la app Atajos del iPad entra por SSH al Mac y conecta Sidecar por Wi-Fi.
- **Pantalla virtual:** sin monitor, el Mac mantiene una pantalla virtual (BetterDisplay) y el iPad la **duplica**. Con solo el iPad y sin virtual, Sidecar se cayó a los pocos segundos en las pruebas.
- **Con un monitor real:** la virtual se apaga y el iPad duplica el monitor.
- **Tailscale (opcional):** reconecta la VPN si quedó parada tras reiniciar.
- El registro de cada intento queda en `~/Library/Logs/pantalla-ipad.log`.

## Piezas

| Archivo | Para qué |
|---|---|
| `pantalla.sh` | `conectar [cable]`, `soltar`, `ajustar`. También acepta órdenes del atajo por SSH. |
| `src/vigilar_cable.swift` | Espera (0 % CPU) a que se enchufe un iPad y vigila cambios de pantallas. |
| `src/espejo.swift` | Duplica una pantalla en otra con CoreGraphics. |
| `tailscale/tailscale-arriba.sh` | Si Tailscale está parado, hace `tailscale up`. |
| `launchd/*.template` | Agentes de launchd; `instalar.sh` los rellena con tu carpeta y tu usuario. |

## Requisitos

- iPad compatible con Sidecar, con la misma cuenta de Apple que el Mac, Wi-Fi y Bluetooth encendidos.
- BetterDisplay (`brew install --cask betterdisplay`) con una pantalla virtual llamada exactamente **`Pantalla iPad`**, y su comando `betterdisplaycli`.
- [SidecarLauncher](https://github.com/Ocasio-J/SidecarLauncher) (MIT, de Jovany Ocasio). **No se incluye aquí.** Se compila desde su código, tras leerlo:
  `swiftc -O main.swift -o SidecarLauncher` y se deja en esta carpeta. Usa partes internas de Sidecar: puede romperse con una actualización de macOS.
- Inicio de sesión automático y, para arrancar sin teclado, FileVault apagado. **Consecuencia:** quien tenga el Mac en la mano entra sin contraseña y el disco no va cifrado. Valóralo según dónde esté el equipo.
- Sesión remota (SSH) activada y Tailscale si se entra desde fuera de casa.

## Instalar

```bash
git clone <este repositorio> && cd ipad-pantalla-mac-mini
./instalar.sh "Nombre de tu iPad"
```

Después carga el agente con el comando que imprime el script. `instalar.sh` no carga nada por sí solo.

## Atajo en el iPad (Wi-Fi, un toque)

1. En Atajos: acción **Ejecutar script por SSH** → autenticación con **llave SSH** → **Generar** → compartir la llave pública.
2. En el Mac, añade esa llave a `~/.ssh/authorized_keys` **restringida**, para que solo pueda conectar o soltar la pantalla:
   ```text
   restrict,command="/ruta/a/ipad-pantalla-mac-mini/pantalla.sh ssh" ssh-ed25519 AAAA… atajo-ipad
   ```
3. En el atajo, el script es `conectar` (o `soltar`).

`pantalla.sh` rechaza cualquier otra orden de esa llave. El atajo responde al instante y el Mac conecta 4 s después: si Sidecar entra mientras el atajo sigue ejecutándose, la sesión se cae.

## Notas de lo que falló

- Un disparador de launchd por `idVendor` o por nombre USB no detecta el iPad en macOS 27; por eso existe `vigilar_cable`.
- `betterdisplaycli set -mirror` falló con la pantalla virtual como origen; por eso existe `espejo`.
- Pasar de Wi-Fi a cable sin desconectar no lo hace Sidecar.
- Sin pruebas todavía: reinicio sin monitor con cable de principio a fin.

## RustDesk

No es parte de este código. Notas: se instala con `brew install --cask rustdesk`, necesita permisos de Grabación de pantalla y Accesibilidad, y una contraseña fija. Si el otro equipo limita los pares permitidos, hay que añadir el ID nuevo con `rustdesk --option` desde un usuario con permisos; editar el archivo de configuración a mano no basta, porque el servicio lo reescribe.

## Licencia

MIT. Sin garantía. Esto toca partes no documentadas de macOS; úsalo bajo tu responsabilidad.
