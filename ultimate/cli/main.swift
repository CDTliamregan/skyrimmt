// ultimate-install: installs ultimate/modlist.json (collection.json format) into its own SkyrimMT profile with
// SkyrimMT's own ModKit (same downloads, FOMOD handling, staging and deploy as a Nexus collection), then sorts the
// plugins with SkyrimMT's LOOT helper. Built by ultimate/ultimate.sh with swiftc; needs Nexus Premium (API downloads).
//   ultimate-install <modlist.json> [--dry-run]
import Foundation

setvbuf(stdout, nil, _IONBF, 0)
let env = ProcessInfo.processInfo.environment
let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: ultimate-install <modlist.json> [--dry-run]"); exit(2) }
let listURL = URL(fileURLWithPath: args[1])
let dryRun = args.contains("--dry-run")
let fm = FileManager.default
// SkyrimMT.app: $SKYRIMMT_APP, else wherever Spotlight finds it (it needn't be in /Applications), else /Applications
let app: URL = {
    if let p = env["SKYRIMMT_APP"] { return URL(fileURLWithPath: p) }
    let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
    p.arguments = ["kMDItemCFBundleIdentifier == 'local.skyrimmt.launcher'"]
    let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
    if (try? p.run()) != nil {
        let d = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        let found = String(decoding: d, as: UTF8.self).split(separator: "\n").map(String.init)
            .first { $0.hasSuffix(".app") && fm.fileExists(atPath: $0 + "/Contents/Helpers/skyrimmt-keyhelper") }
        if let found { return URL(fileURLWithPath: found) }
    }
    return URL(fileURLWithPath: "/Applications/SkyrimMT.app")
}()

func fail(_ s: String) -> Never { print("ERROR: \(s)"); exit(1) }

// ---- the list
guard let data = try? Data(contentsOf: listURL) else { fail("can't read \(listURL.path)") }
var manifest: CollectionManifest
do { manifest = try CollectionManifest.parse(data) } catch { fail("bad modlist: \(error)") }
let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
let rawMods = raw["mods"] as? [[String: Any]] ?? []
var files: [CollectionFile] = []
for (i, m) in manifest.mods.enumerated() {
    let src = rawMods[i]["source"] as? [String: Any] ?? [:]
    guard let mid = m.modID, let fid = m.fileID else { fail("\(m.name): no modId/fileId") }
    files.append(CollectionFile(modID: mid, fileID: fid, modName: m.name, fileName: m.name, version: src["version"] as? String ?? "",
                                size: (src["fileSize"] as? NSNumber)?.int64Value ?? 0, optional: false))
}
let total = files.reduce(Int64(0)) { $0 + $1.size }
let info = CollectionInfo(slug: "ultimate-skyrim", name: manifest.name.isEmpty ? "Ultimate Skyrim" : manifest.name, revision: 1,
                          downloadLink: "", gameVersions: [(raw["info"] as? [String: Any])?["gameVersion"] as? String ?? ""],
                          totalSize: total, files: files)
print("List: \(info.name), \(files.count) files, \(total / 1_073_741_824) GB to download")

// ---- SkyrimMT's game folder
let gameHome = env["SKYRIMMT_HOME"]
    ?? UserDefaults(suiteName: "local.skyrimmt.launcher")?.string(forKey: "gameHome")
    ?? NSHomeDirectory() + "/Games/skyrim"
let home = URL(fileURLWithPath: gameHome)
guard fm.fileExists(atPath: home.appendingPathComponent("prefix").path) else { fail("no SkyrimMT game folder at \(home.path): run Setup → Set up everything first") }
let kit = ModKit.standard(home: home)
guard fm.fileExists(atPath: kit.gameDir.appendingPathComponent("SkyrimSE.exe").path) else { fail("Skyrim isn't installed in \(kit.gameDir.path)") }
print("Game folder: \(kit.gameDir.path) (version key \(kit.gameVersionKey))")
print("SkyrimMT app: \(app.path)")

// ---- Nexus key: env, then SkyrimMT's Keychain helper, then the Keychain directly
func keyFromHelper() -> String? {
    let h = app.appendingPathComponent("Contents/Helpers/skyrimmt-keyhelper")
    guard fm.isExecutableFile(atPath: h.path) else { return nil }
    let p = Process(); p.executableURL = h; p.arguments = ["get"]
    let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return nil }
    let d = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
    let s = String(decoding: d, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    return p.terminationStatus == 0 && !s.isEmpty ? s : nil
}
guard let key = env["NEXUS_API_KEY"] ?? keyFromHelper() ?? NexusKeychain.load() else {
    fail("no Nexus API key: open SkyrimMT → Mod Manager → Essentials and add your key, then run this again")
}
let client = NexusClient(apiKey: key, appVersion: "ultimate-1")

let sem = DispatchSemaphore(value: 0)
var exitCode: Int32 = 0
Task {
    defer { sem.signal() }
    do {
        let user = try await client.validate()
        print("Nexus: \(user.name)\(user.premium ? " (Premium)" : "")")
        guard user.premium else { print("ERROR: Nexus Premium is needed for unattended downloads"); exitCode = 1; return }
        if dryRun {
            // check every pinned file still exists and is downloadable
            var bad = 0
            for f in files {
                do { _ = try await client.downloadURLs(modID: f.modID, fileID: f.fileID, key: nil, expires: nil) }
                catch { bad += 1; print("  MISSING \(f.modName) (\(f.modID)/\(f.fileID)): \(error)") }
            }
            print(bad == 0 ? "Dry run OK: all \(files.count) files are downloadable." : "Dry run: \(bad) files not downloadable.")
            exitCode = bad == 0 ? 0 : 1
            return
        }
        let items = manifest.mods
        let started = Date()
        let profile = try await kit.installCollection(info: info, manifest: manifest, items: items, client: client, gameVersion: "",
                                                      progress: { i, s in
            let n = items[i].name
            switch s {
            case .installing: print("  installing  \(n)")
            case .done: print("  done        \(n)")
            case .reused: print("  reused      \(n)")
            case .skipped(let why): print("  SKIPPED     \(n): \(why)")
            case .failed(let why): print("  FAILED      \(n): \(why)")
            case .downloading(nil): print("  downloading \(n)")
            default: break
            }
        })
        print("Installed into profile “\(profile)” in \(Int(Date().timeIntervalSince(started) / 60)) min")
        let loot = app.appendingPathComponent("Contents/Helpers/skyrimmt-loot")
        do {
            let r = try kit.lootSort(helper: loot)
            print("LOOT: sorted \(r.sorted.count) plugins, moved \(r.moved)")
        } catch { print("WARNING: LOOT sort failed (\(error)); sort once in SkyrimMT → Plugins → Sort") }
        try kit.deploy()
        let failed = kit.installedCollections().first { $0.slug == info.slug }?.failed ?? []
        if failed.isEmpty { print("ALL DONE: open SkyrimMT and press Play.") }
        else { print("DONE WITH \(failed.count) FAILED: \(failed.joined(separator: ", "))"); exitCode = 3 }
    } catch {
        print("ERROR: \(error)"); exitCode = 1
    }
}
sem.wait()
exit(exitCode)
