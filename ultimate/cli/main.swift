// ultimate-install: installs ultimate/modlist.json (collection.json format) into its own SkyrimMT profile with
// SkyrimMT's own ModKit (same downloads, FOMOD handling, staging and deploy as a Nexus collection), then sorts the
// plugins with SkyrimMT's LOOT helper. Built by ultimate/ultimate.sh with swiftc. Nexus Premium downloads everything
// itself; a free account installs once every file is in the downloads folder (ultimate.sh fetch: one click per file).
//   ultimate-install <modlist.json> [--dry-run | --missing] [--available]
//   --missing: no network, no key; prints "modID fileID name" for each file not yet in the downloads folder
//   --available: install only the files already in the downloads folder, leaving out any entry whose requirements
//                (ultimate/deps.json) are left out; with --dry-run it only prints that plan
import Foundation

setvbuf(stdout, nil, _IONBF, 0)
let env = ProcessInfo.processInfo.environment
let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: ultimate-install <modlist.json> [--dry-run | --missing] [--available]"); exit(2) }
let listURL = URL(fileURLWithPath: args[1])
let dryRun = args.contains("--dry-run")
let missingOnly = args.contains("--missing")
let availableOnly = args.contains("--available")
func say(_ s: String) { if !missingOnly { print(s) } }   // --missing prints only the missing-file lines
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
    if m.sourceType == "bundle" { continue }   // official files fetched by URL (below), not from Nexus
    guard let mid = m.modID, let fid = m.fileID else { fail("\(m.name): no modId/fileId") }
    // size 0: the list's sizes are rounded to whole KB, and a known size makes existingDownload demand an exact byte
    // match, so archives downloaded by hand (nxm) would never be recognised. The real size only feeds the total.
    files.append(CollectionFile(modID: mid, fileID: fid, modName: m.name, fileName: m.name, version: src["version"] as? String ?? "",
                                size: 0, optional: false))
}
let total = rawMods.reduce(Int64(0)) { $0 + ((($1["source"] as? [String: Any])?["fileSize"] as? NSNumber)?.int64Value ?? 0) }
var info = CollectionInfo(slug: "ultimate-skyrim", name: manifest.name.isEmpty ? "Ultimate Skyrim" : manifest.name, revision: 1,
                          downloadLink: "", gameVersions: [(raw["info"] as? [String: Any])?["gameVersion"] as? String ?? ""],
                          totalSize: total, files: files)
say("List: \(info.name), \(files.count) files, \(total / 1_073_741_824) GB to download")

// ---- SkyrimMT's game folder
let gameHome = env["SKYRIMMT_HOME"]
    ?? UserDefaults(suiteName: "local.skyrimmt.launcher")?.string(forKey: "gameHome")
    ?? NSHomeDirectory() + "/Games/skyrim"
let home = URL(fileURLWithPath: gameHome)
guard fm.fileExists(atPath: home.appendingPathComponent("prefix").path) else { fail("no SkyrimMT game folder at \(home.path): run Setup → Set up everything first") }
let kit = ModKit.standard(home: home)
guard fm.fileExists(atPath: kit.gameDir.appendingPathComponent("SkyrimSE.exe").path) else { fail("Skyrim isn't installed in \(kit.gameDir.path)") }
say("Game folder: \(kit.gameDir.path) (version key \(kit.gameVersionKey))")

// ---- "bundle" entries: official archives from a fixed URL (e.g. a mod's GitHub release), unpacked into a bundle
// folder that ModKit's collection installer installs from (bundled/<entry name>), so no Nexus download is needed
let bundleDir = home.appendingPathComponent("cache/ultimate-bundle")
func prepareBundles() -> [String] {
    var failed: [String] = []
    for m in manifest.mods where m.sourceType == "bundle" {
        let out = bundleDir.appendingPathComponent("bundled/\(m.name)")
        if fm.fileExists(atPath: out.path) { continue }
        guard let s = m.url, let u = URL(string: s) else { failed.append("\(m.name): no url"); continue }
        let arch = bundleDir.appendingPathComponent("archives/\(u.lastPathComponent)")
        try? fm.createDirectory(at: arch.deletingLastPathComponent(), withIntermediateDirectories: true)
        func run(_ a: [String]) -> Bool { let p = Process(); p.executableURL = URL(fileURLWithPath: a[0]); p.arguments = Array(a.dropFirst())
            p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
            return (try? p.run()) != nil && { p.waitUntilExit(); return p.terminationStatus == 0 }() }
        if !fm.fileExists(atPath: arch.path) && !run(["/usr/bin/curl", "-sfL", "--max-time", "600", "-o", arch.path, s]) {
            try? fm.removeItem(at: arch); failed.append("\(m.name): download failed"); continue }
        let tmp = out.appendingPathExtension("tmp"); try? fm.removeItem(at: tmp)
        try? fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        if run(["/usr/bin/bsdtar", "-xf", arch.path, "-C", tmp.path]) { try? fm.moveItem(at: tmp, to: out) }
        else { try? fm.removeItem(at: tmp); try? fm.removeItem(at: arch); failed.append("\(m.name): couldn't unpack") }
    }
    try? fm.createDirectory(at: bundleDir, withIntermediateDirectories: true)
    try? fm.removeItem(at: bundleDir.appendingPathComponent("collection.json"))
    try? fm.copyItem(at: listURL, to: bundleDir.appendingPathComponent("collection.json"))
    manifest.bundleDir = bundleDir
    return failed
}
say("SkyrimMT app: \(app.path)")

// ---- files not yet in SkyrimMT's downloads folder (matched by the .meta.json SkyrimMT writes for each download)
func missingFiles() -> [CollectionFile] {
    let local = NexusDownloader(client: NexusClient(apiKey: nil, appVersion: "ultimate-1"), folder: kit.home.appendingPathComponent("downloads"))
    return files.filter { local.existingDownload(modID: $0.modID, fileID: $0.fileID, md5: nil, size: nil) == nil }
}
if missingOnly {
    for f in missingFiles() { print("\(f.modID) \(f.fileID) \(f.modName)") }
    exit(0)
}

// ---- --available: only what's downloaded, minus every entry whose requirements are left out (ultimate/deps.json)
if availableOnly {
    let depsURL = listURL.deletingLastPathComponent().appendingPathComponent("deps.json")
    let deps = (try? JSONSerialization.jsonObject(with: Data(contentsOf: depsURL))) as? [String: Any] ?? [:]
    var needsMods: [Int: [Int]] = [:], needsFiles: [Int: [Int]] = [:]
    for (k, v) in deps { if let id = Int(k), let l = v as? [Int] { needsMods[id] = l } }
    for (k, v) in deps["_files"] as? [String: Any] ?? [:] { if let id = Int(k), let l = v as? [Int] { needsFiles[id] = l } }
    let allFiles = files
    func label(mod: Int) -> String { allFiles.first { $0.modID == mod }?.modName ?? "mod \(mod)" }
    func label(file: Int) -> String { allFiles.first { $0.fileID == file }?.modName ?? "file \(file)" }
    var why: [Int: String] = [:]
    for f in missingFiles() { why[f.fileID] = "not downloaded" }
    var keep = Set(allFiles.map(\.fileID)).subtracting(why.keys)
    var changed = true
    while changed {
        changed = false
        for f in allFiles where keep.contains(f.fileID) {
            let lackMod = (needsMods[f.modID] ?? []).first { m in m != f.modID && !allFiles.contains { $0.modID == m && keep.contains($0.fileID) } }
            let lackFile = (needsFiles[f.fileID] ?? []).first { !keep.contains($0) }
            if let m = lackMod { why[f.fileID] = "needs \(label(mod: m))" } else if let x = lackFile { why[f.fileID] = "needs \(label(file: x))" } else { continue }
            keep.remove(f.fileID); changed = true
        }
    }
    say("Available: \(keep.count) of \(allFiles.count) files can be installed.")
    for f in allFiles where !keep.contains(f.fileID) { say("  left out   \(f.modName): \(why[f.fileID] ?? "")") }
    for f in allFiles where keep.contains(f.fileID) { say("  install    \(f.modName)") }
    if keep.isEmpty { print("Nothing can be installed yet: every downloaded file needs something that isn't downloaded."); exit(5) }
    if dryRun { exit(0) }
    manifest.mods = manifest.mods.filter { $0.fileID.map(keep.contains) ?? false }
    files = allFiles.filter { keep.contains($0.fileID) }
    info = CollectionInfo(slug: info.slug, name: info.name, revision: info.revision, downloadLink: info.downloadLink,
                          gameVersions: info.gameVersions, totalSize: info.totalSize, files: files)
}

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
        if !user.premium {
            // free account: Nexus allows no API downloads, so every file must already be in the downloads folder
            let missing = missingFiles()
            if dryRun {
                print("Free account: \(files.count - missing.count)/\(files.count) files already downloaded, \(missing.count) missing.")
                exitCode = missing.isEmpty ? 0 : 4
                return
            }
            if !missing.isEmpty {
                for f in missing { print("  MISSING \(f.modName) (\(f.modID)/\(f.fileID))") }
                print("Free account: download these first (ultimate.sh fetch)")
                exitCode = 4
                return
            }
            print("Free account: all \(files.count) files are in the downloads folder; installing from there.")
        } else if dryRun {
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
        for f in prepareBundles() { print("  SKIPPED     \(f)") }
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
        // entries marked "enabled": false (graphics add-ons to be tried one at a time) stay installed but switched off
        let off = Set(rawMods.filter { ($0["enabled"] as? Bool) == false }.compactMap { m -> String? in
            guard let src = m["source"] as? [String: Any], let mid = (src["modId"] as? NSNumber)?.intValue,
                  let fid = (src["fileId"] as? NSNumber)?.intValue else { return nil }
            return "\(mid):\(fid)"
        })
        let offNames = Set(rawMods.filter { ($0["enabled"] as? Bool) == false }.compactMap { $0["name"] as? String })
        if !(off.isEmpty && offNames.isEmpty), var prof = kit.profile(profile) {
            let ids = Set(kit.mods.filter { r in (r.nexus.map { off.contains("\($0.modID):\($0.fileID ?? -1)") } ?? false) || (r.nexus == nil && offNames.contains(r.name)) }.map(\.id))
            var n = 0
            for i in prof.mods.indices where ids.contains(prof.mods[i].id) && prof.mods[i].enabled { prof.mods[i].enabled = false; n += 1 }
            if n > 0 { try kit.saveProfile(prof); try kit.deploy(prof); print("Left \(n) add-on(s) installed but disabled (enable them one at a time)") }
        }
        let masters = kit.missingMasters()
        for m in masters { print("MISSING MASTER \(m.master), needed by \(m.neededBy.joined(separator: ", "))") }
        if !masters.isEmpty { exitCode = 3 }
        let failed = kit.installedCollections().first { $0.slug == info.slug }?.failed ?? []
        if failed.isEmpty && masters.isEmpty { print("ALL DONE: open SkyrimMT and press Play.") }
        else if failed.isEmpty { print("DONE, BUT PLUGINS ARE MISSING MASTERS (above)") }
        else { print("DONE WITH \(failed.count) FAILED: \(failed.joined(separator: ", "))"); exitCode = 3 }
    } catch {
        print("ERROR: \(error)"); exitCode = 1
    }
}
sem.wait()
exit(exitCode)
