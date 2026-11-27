// nxm-handler: which app opens nxm:// links (Nexus "Mod Manager Download"), and making SkyrimMT that app.
//   nxm-handler get            prints the app path Launch Services opens nxm:// links with (exit 1 if none)
//   nxm-handler set <app path> makes that app the nxm:// handler (macOS may ask you to confirm)
import AppKit

let args = CommandLine.arguments
let probe = URL(string: "nxm://skyrimspecialedition/mods/1/files/1")!
switch args.count > 1 ? args[1] : "" {
case "get":
    guard let app = NSWorkspace.shared.urlForApplication(toOpen: probe) else { exit(1) }
    print(app.path)
case "set" where args.count > 2:
    let app = URL(fileURLWithPath: args[2])
    let done = DispatchSemaphore(value: 0)
    var failed: Error?
    NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "nxm") { error in failed = error; done.signal() }
    // the completion runs after any confirmation dialog; keep the run loop alive for it
    while done.wait(timeout: .now()) == .timedOut { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
    if let failed { FileHandle.standardError.write(Data("nxm-handler: \(failed)\n".utf8)); exit(1) }
default:
    print("usage: nxm-handler get | set <app path>"); exit(2)
}
