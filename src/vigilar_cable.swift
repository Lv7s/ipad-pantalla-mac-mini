// vigilar_cable · se queda dormido esperando a que IOKit avise que se enchufó
// un iPad por USB (no consume CPU mientras espera) y entonces ejecuta
// pantalla.sh conectar cable. También actúa si el iPad ya estaba enchufado
// al iniciar sesión. Sustituye a un disparador por evento de launchd, porque ese
// evento no llegaba al enchufar el cable en macOS 27.
import Foundation
import IOKit
import IOKit.usb
import AppKit

// pantalla.sh vive en la misma carpeta que este ejecutable.
let script = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    .appendingPathComponent("pantalla.sh").path

func conectar() {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = [script, "conectar", "cable"]
    try? p.run()   // no se espera: pantalla.sh ya evita ejecuciones duplicadas
}

let port = IONotificationPortCreate(kIOMainPortDefault)
CFRunLoopAddSource(CFRunLoopGetMain(),
                   IONotificationPortGetRunLoopSource(port).takeUnretainedValue(),
                   .commonModes)

// IOKit avisa de cualquier dispositivo USB que se enchufe y aquí se filtra
// por nombre «iPad». (Filtrar por idVendor o por nombre en el propio
// emparejamiento no devuelve nada en macOS 27: comprobado el 20-11-2026.)
let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary

var iter: io_iterator_t = 0
let callback: IOServiceMatchingCallback = { _, iterator in
    var hubo = false
    while case let s = IOIteratorNext(iterator), s != 0 {
        if let n = IORegistryEntryCreateCFProperty(s, "USB Product Name" as CFString,
                                                   kCFAllocatorDefault, 0)?
                     .takeRetainedValue() as? String, n == "iPad" {
            hubo = true
        }
        IOObjectRelease(s)
    }
    if hubo { conectar() }
}

IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, matching,
                                 callback, nil, &iter)
// Vaciar el iterador arma la notificación y trata el iPad ya enchufado.
callback(nil, iter)

// Cambios de pantallas (monitor enchufado o quitado, Sidecar que entra o sale):
// 3 s después de la última novedad se ejecuta pantalla.sh ajustar, que enciende
// o apaga la pantalla virtual según haga falta.
var pendiente: DispatchWorkItem?
func programarAjuste() {
    pendiente?.cancel()
    let w = DispatchWorkItem {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = [script, "ajustar"]
        try? p.run()
    }
    pendiente = w
    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
}
// Los avisos de pantallas solo llegan con el bucle de AppKit (sin él, en
// macOS 27 no llega ninguno: comprobado el 20-11-2026). Sin icono ni ventana.
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
    if !flags.contains(.beginConfigurationFlag) { programarAjuste() }
}, nil)
programarAjuste()   // también al iniciar sesión
app.run()
