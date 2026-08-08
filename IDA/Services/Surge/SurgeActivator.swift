import Foundation
import AppKit

@objc enum SurgeActivationStatus: Int {
    case unknown = 0
    case notActivated = 1
    case activated = 2
    case failed = 3
}

@objc class SurgeAppInfo: NSObject {
    @objc let path: String
    @objc let version: String
    @objc var activationStatus: SurgeActivationStatus

    init(path: String, version: String, activationStatus: SurgeActivationStatus) {
        self.path = path
        self.version = version
        self.activationStatus = activationStatus
        super.init()
    }

    var displayName: String {
        version.isEmpty ? "Surge" : "Surge \(version)"
    }

    var macosDir: String {
        (path as NSString).appendingPathComponent("Contents/MacOS")
    }

    var bundleID: String {
        "com.nssurge.mac"
    }
}

@objc class SurgeActivator: NSObject {

    static let shared = SurgeActivator()

    private override init() {
        super.init()
    }

    private static let decryptKeys: [[UInt8]] = [
        [0x5A, 0xC3, 0x91, 0x7E, 0xB2, 0x4F, 0x8D, 0x16],
        [0x9F, 0x27, 0x6E, 0xC8, 0x31, 0xA4, 0x5D, 0xF2],
        [0x73, 0x1B, 0xE8, 0x44, 0x9C, 0x6A, 0x2F, 0xD1],
    ]

    private static func rotateLeft(_ b: UInt8, _ n: Int) -> UInt8 {
        return (b << UInt8(n)) | (b >> UInt8(8 - n))
    }

    private static func rotateRight(_ b: UInt8, _ n: Int) -> UInt8 {
        return (b >> UInt8(n)) | (b << UInt8(8 - n))
    }

    private static func decryptPxxDylib(_ data: Data) -> Data? {
        guard data.count > 12 else { return nil }
        let magic = String(data: data.prefix(4), encoding: .ascii)
        guard magic == "PXDX" else { return nil }

        let sizeData = data.subdata(in: 8..<12)
        let originalSize = sizeData.withUnsafeBytes { rawPtr -> Int in
            let ptr = rawPtr.bindMemory(to: UInt32.self)
            return Int(ptr[0])
        }

        var encrypted = [UInt8](data.dropFirst(12))
        guard encrypted.count == originalSize else { return nil }

        for roundIdx in (0..<3).reversed() {
            let key = decryptKeys[roundIdx]
            var result = [UInt8](repeating: 0, count: encrypted.count)
            for i in 0..<encrypted.count {
                var b = encrypted[i]
                b = rotateRight(b, (i + roundIdx) % 7 + 1)
                b ^= key[i % key.count]
                result[i] = b
            }
            encrypted = result
        }

        return Data(encrypted)
    }

    func detectApps() -> [SurgeAppInfo] {
        var results: [SurgeAppInfo] = []
        var seenPaths = Set<String>()

        let searchDirs = [
            "/Applications",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications"),
            (NSHomeDirectory() as NSString).appendingPathComponent("Desktop"),
            (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")
        ]

        let fm = FileManager.default

        for dir in searchDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for name in contents {
                if name.hasPrefix("Surge") && name.hasSuffix(".app") {
                    let appPath = (dir as NSString).appendingPathComponent(name)
                    let realPath = (appPath as NSString).resolvingSymlinksInPath
                    if seenPaths.contains(realPath) { continue }
                    seenPaths.insert(realPath)

                    let version = extractVersion(from: name)
                    let macosDir = (realPath as NSString).appendingPathComponent("Contents/MacOS")

                    let hasSurge = fm.fileExists(atPath: (macosDir as NSString).appendingPathComponent("Surge"))
                    guard hasSurge else { continue }

                    let status = checkActivation(appPath: realPath)
                    results.append(SurgeAppInfo(path: realPath, version: version, activationStatus: status))
                }
            }
        }

        return results.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    private func extractVersion(from name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "Surge", with: "")
            .replacingOccurrences(of: ".app", with: "")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "" : cleaned
    }

    private func checkActivation(appPath: String) -> SurgeActivationStatus {
        let plistPath = (NSHomeDirectory() as NSString).appendingPathComponent(
            "Library/Preferences/com.nssurge.surge-mac.plist"
        )
        let fm = FileManager.default
        guard fm.fileExists(atPath: plistPath) else {
            return .notActivated
        }
        guard let dict = NSDictionary(contentsOfFile: plistPath) else {
            return .notActivated
        }

        if let licenseType = dict["licenseType"] as? Int, licenseType > 0 {
            return .activated
        }
        if let _ = dict["License"] as? [String: Any] {
            return .activated
        }
        return .notActivated
    }

    func activate(app: SurgeAppInfo,
                  progress: @escaping (String) -> Void,
                  completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let bundle = Bundle.main
            let fm = FileManager.default
            let tmpDir = NSTemporaryDirectory() + "surge_act_\(UUID().uuidString)"

            do {
                try fm.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
                defer { try? fm.removeItem(atPath: tmpDir) }

                guard let pxxBinPath = bundle.path(forResource: "pxx", ofType: "bin") else {
                    DispatchQueue.main.async {
                        completion(false, "资源文件缺失")
                    }
                    return
                }

                progress("正在检查系统环境...")
                
                let sipEnabled = surge_check_sip_enabled()

                if sipEnabled {
                    progress("ℹ️  SIP（系统完整性保护）已开启")
                    progress("ℹ️  使用 Mach 内核级注入")
                } else {
                    progress("✅ SIP 已关闭（Mach 注入）")
                }

                progress("正在加载核心模块...")
                
                guard let encData = NSData(contentsOfFile: pxxBinPath) as Data? else {
                    throw NSError(domain: "SurgeActivator", code: -1, userInfo: [NSLocalizedDescriptionKey: "核心模块加载失败"])
                }
                
                guard let dylibData = Self.decryptPxxDylib(encData) else {
                    throw NSError(domain: "SurgeActivator", code: -2, userInfo: [NSLocalizedDescriptionKey: "核心模块解密失败"])
                }

                let cacheDir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Caches/com.pxx917144686.IDA-Surge")
                try fm.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
                let dylibPath = cacheDir + "/pxx.dylib"
                try dylibData.write(to: URL(fileURLWithPath: dylibPath), options: .atomic)
                
                let cs = Process()
                cs.launchPath = "/usr/bin/codesign"
                cs.arguments = ["-fs-", "--deep", dylibPath]
                try? cs.run()
                cs.waitUntilExit()
                
                let xa = Process()
                xa.launchPath = "/usr/bin/xattr"
                xa.arguments = ["-cr", dylibPath]
                try? xa.run()
                xa.waitUntilExit()
                
                let surgeBin = app.macosDir + "/Surge"
                guard fm.fileExists(atPath: surgeBin) else {
                    DispatchQueue.main.async {
                        completion(false, "未找到 Surge 可执行文件")
                    }
                    return
                }
                
                progress("正在关闭已运行的 Surge...")
                self.terminateSurge(app: app)
                
                progress("正在激活 Surge (Mach 内核注入)...")
                do {
                    try self.activateWithMachInject(surgeBin: surgeBin, dylibPath: dylibPath, progress: progress)
                    progress("✅ 注入成功，授权模块已加载")
                } catch {
                    DispatchQueue.main.async {
                        completion(false, "激活失败: \(error.localizedDescription)")
                    }
                    return
                }

                Thread.sleep(forTimeInterval: 3)
                
                let runningApps = NSWorkspace.shared.runningApplications
                for runningApp in runningApps {
                    if runningApp.bundleIdentifier == app.bundleID {
                        runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                        break
                    }
                }
                
                self.fixHelper(progress: progress)

                DispatchQueue.main.async {
                    completion(true, "Surge 激活成功，已启动")
                }

            } catch {
                DispatchQueue.main.async {
                    completion(false, "激活失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func terminateSurge(app: SurgeAppInfo) {
        let ws = NSWorkspace.shared
        let apps = ws.runningApplications
        for a in apps {
            if a.bundleIdentifier == app.bundleID {
                a.terminate()
            }
        }
        Thread.sleep(forTimeInterval: 1.5)
    }

    private func activateWithMachInject(surgeBin: String, dylibPath: String, progress: @escaping (String) -> Void) throws {
        progress("→ 启动 Surge...")
        
        var errorMsgC: UnsafeMutablePointer<Int8>? = nil
        var spawnedPid: pid_t = 0
        let ret = surge_spawn_and_inject(surgeBin, dylibPath, &errorMsgC, &spawnedPid)
        
        if ret != 0 {
            let msg: String
            if let errPtr = errorMsgC {
                msg = String(cString: errPtr)
                free(errPtr)
            } else {
                msg = "注入失败 (code=\(ret))"
            }
            throw NSError(domain: "SurgeMachInject", code: Int(ret), userInfo: [
                NSLocalizedDescriptionKey: msg
            ])
        }
        
        progress("→ 等待进程就绪...")
        Thread.sleep(forTimeInterval: 2)
        let checkPid = Process()
        checkPid.launchPath = "/bin/kill"
        checkPid.arguments = ["-0", String(spawnedPid)]
        let pipe = Pipe()
        checkPid.standardError = pipe
        checkPid.standardOutput = pipe
        do {
            try checkPid.run()
            checkPid.waitUntilExit()
            if checkPid.terminationStatus != 0 {
                throw NSError(domain: "SurgeMachInject", code: -99, userInfo: [
                    NSLocalizedDescriptionKey: "注入后进程已退出 (PID=\(spawnedPid))"
                ])
            }
        } catch {
            throw NSError(domain: "SurgeMachInject", code: -98, userInfo: [
                NSLocalizedDescriptionKey: "无法验证进程状态: \(error.localizedDescription)"
            ])
        }
        progress("✅ 进程已成功启动 (PID=\(spawnedPid))")
    }
    
    private func fixHelper(progress: @escaping (String) -> Void) {
        progress("正在修复系统代理权限...")

        let helperPlist = "/Library/LaunchDaemons/com.nssurge.surge-mac.helper.plist"
        let helperLabel = "com.nssurge.surge-mac.helper"
        let fm = FileManager.default

        guard fm.fileExists(atPath: helperPlist) else {
            progress("Helper 尚未安装，Surge 首次启用系统代理时自动安装")
            return
        }

        let check = Process()
        check.launchPath = "/bin/launchctl"
        check.arguments = ["print", "system/\(helperLabel)"]
        let pipe = Pipe()
        check.standardOutput = pipe
        do {
            try check.run()
            check.waitUntilExit()
            if check.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if output.contains("state = running") {
                    progress("系统代理权限已就绪 (Helper 运行中)")
                    return
                }
            }
        } catch {}

        let cmds: [[String]] = [
            ["/bin/launchctl", "bootstrap", "system", helperPlist],
            ["/bin/launchctl", "kickstart", "-k", "system/\(helperLabel)"],
            ["/bin/launchctl", "load", "-w", helperPlist]
        ]

        var lastOk = false
        for (idx, argv) in cmds.enumerated() {
            let script = "do shell script \"\(argv.joined(separator: " "))\" with administrator privileges"
            var err: NSDictionary?
            autoreleasepool {
                if let ascr = NSAppleScript(source: script) {
                    ascr.executeAndReturnError(&err)
                }
            }
            if err == nil {
                lastOk = true
                Thread.sleep(forTimeInterval: 0.3)
            } else if idx == cmds.count - 1 && !lastOk {
                progress("Helper 修复失败（可在 Surge 内启用系统代理时按提示安装）")
                return
            }
        }
        progress(lastOk ? "系统代理权限修复成功" : "系统代理权限修复完成")
    }
}
