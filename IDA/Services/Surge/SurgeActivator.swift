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
        "Surge \(version)"
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
        return cleaned.isEmpty ? "5.x" : cleaned
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

                progress("正在加载核心模块...")

                guard let encData = NSData(contentsOfFile: pxxBinPath) as Data? else {
                    throw NSError(domain: "SurgeActivator", code: -1, userInfo: [NSLocalizedDescriptionKey: "核心模块加载失败"])
                }

                guard let dylibData = Self.decryptPxxDylib(encData) else {
                    throw NSError(domain: "SurgeActivator", code: -2, userInfo: [NSLocalizedDescriptionKey: "核心模块解密失败"])
                }

                let dylibPath = tmpDir + "/pxx.dylib"
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

                progress("正在激活 Surge...")
                do {
                    try self.activateWithDYLDInject(surgeBin: surgeBin, dylibPath: dylibPath, progress: progress)
                } catch {
                    let sipEnabled = surge_check_sip_enabled()
                    let errorMsg: String
                    if sipEnabled {
                        errorMsg = "激活失败，可能是 SIP 已开启导致的。\n\nSIP（System Integrity Protection）是 macOS 的系统完整性保护机制，开启状态下可能无法进行进程注入操作。\n\n建议关闭 SIP 后重试：\n1. 重启 Mac 并按住 Command + R 进入恢复模式\n2. 打开终端，执行：csrutil disable\n3. 重启 Mac 后再次尝试激活\n\n原始错误: \(error.localizedDescription)"
                    } else {
                        errorMsg = "激活失败: \(error.localizedDescription)"
                    }
                    DispatchQueue.main.async {
                        completion(false, errorMsg)
                    }
                    return
                }

                Thread.sleep(forTimeInterval: 3)
                
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

    private func activateWithDYLDInject(surgeBin: String, dylibPath: String, progress: @escaping (String) -> Void) throws {
        progress("正在注入并启动 Surge...")
        
        let task = Process()
        task.launchPath = surgeBin
        
        var env = ProcessInfo.processInfo.environment
        env["DYLD_INSERT_LIBRARIES"] = dylibPath
        env["DYLD_FORCE_FLAT_NAMESPACE"] = "1"
        task.environment = env
        
        task.launch()
        
        Thread.sleep(forTimeInterval: 2)
        
        if !task.isRunning {
            let status = task.terminationStatus
            throw NSError(domain: "SurgeActivator", code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "Surge 启动失败 (exit code: \(status))"
            ])
        }
    }
    
    private func fixHelper(progress: @escaping (String) -> Void) {
        progress("正在修复系统代理权限...")
        
        let script = """
        do shell script "/bin/launchctl load -w /Library/LaunchDaemons/com.nssurge.surge-mac.helper.plist" with administrator privileges
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if error != nil {
                progress("Helper 修复失败（可稍后手动修复）")
            } else {
                progress("系统代理权限修复成功")
            }
        }
    }
}
