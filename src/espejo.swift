// espejo · hace que una pantalla duplique a otra con CoreGraphics (lo mismo
// que «Duplicar» en Ajustes). Uso: espejo <displayID origen> <displayID copia>
// La copia muestra lo mismo que el origen. Los displayID los da
// `betterdisplaycli get -identifiers`. Sin argumentos lista las pantallas.
// Existe porque «betterdisplaycli set -mirror» falló con la pantalla virtual
// como origen.
import AppKit

_ = NSApplication.shared
var n: UInt32 = 0
CGGetOnlineDisplayList(0, nil, &n)
var ids = [CGDirectDisplayID](repeating: 0, count: Int(n))
CGGetOnlineDisplayList(n, &ids, &n)

let args = CommandLine.arguments
if args.count < 2 {
    for id in ids {
        print("\(id)\t\(CGDisplayPixelsWide(id))x\(CGDisplayPixelsHigh(id))\tprincipal=\(CGDisplayIsMain(id) != 0)\tespejo_de=\(CGDisplayMirrorsDisplay(id))")
    }
    exit(0)
}
// «ipad» = la pantalla Sidecar: macOS la marca con modelo 0x69506164 («iPad»).
// BetterDisplay no siempre le da displayID (sin monitor real no lo dio, 14:46).
func resolver(_ a: String) -> UInt32? {
    if a.lowercased() == "ipad" { return ids.first { CGDisplayModelNumber($0) == 0x69506164 } }
    return UInt32(a)
}
if args.count == 2 && args[1].lowercased() == "ipad" {
    if let i = resolver("ipad") { print(i); exit(0) } else { exit(1) }
}
guard let origen = resolver(args[1]), let copia = resolver(args[2]),
      ids.contains(origen), ids.contains(copia) else {
    print("Pantallas no encontradas: \(args[1]) \(args[2]) (en línea: \(ids))"); exit(2)
}

var config: CGDisplayConfigRef?
guard CGBeginDisplayConfiguration(&config) == .success else { print("Error al empezar"); exit(3) }
let r = CGConfigureDisplayMirrorOfDisplay(config, copia, origen)
guard r == .success else { CGCancelDisplayConfiguration(config); print("Error al duplicar: \(r.rawValue)"); exit(4) }
let c = CGCompleteDisplayConfiguration(config, .permanently)
print(c == .success ? "duplicando \(origen) → \(copia)" : "Error al aplicar: \(c.rawValue)")
exit(c == .success ? 0 : 5)
