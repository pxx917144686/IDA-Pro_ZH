import Foundation
import SwiftUI
import Combine

enum AppSection: String, CaseIterable, Identifiable {
    case localization = "汉化管理"
    case translation = "翻译管理"
    case activation = "IDA激活"
    case surgeActivation = "Surge激活"
    case about = "关于"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .localization: return "globe"
        case .translation: return "character.book.closed.fill"
        case .activation: return "key.fill"
        case .surgeActivation: return "bolt.shield.fill"
        case .about: return "info.circle"
        }
    }
}

struct IDAAppModel: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let version: String
    let localizationStatus: String
    let activationStatus: String

    var name: String {
        (path as NSString).lastPathComponent
    }

    var displayName: String {
        "IDA Professional \(version)"
    }

    static func == (lhs: IDAAppModel, rhs: IDAAppModel) -> Bool {
        lhs.path == rhs.path
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var currentSection: AppSection = .localization
    @Published var idaApps: [IDAAppModel] = []
    @Published var selectedApp: IDAAppModel?
    @Published var isProcessing = false
    @Published var logOutput = ""
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    let audioManager = AudioManager.shared

    @Published var surgeApps: [SurgeAppInfo] = []
    @Published var selectedSurgeApp: SurgeAppInfo?
    @Published var isSurgeProcessing = false
    @Published var surgeLogOutput = ""
    
    @Published var useCustomIcon = false {
        didSet {
            
            if useCustomIcon {
                GIFDockAnimator.shared.start()
            } else {
                GIFDockAnimator.shared.stop()
            }
            updateAppIcon()
        }
    }

    @Published var userName = "auth"
    @Published var userEmail = "admin@hex-rays.com"
    @Published var expiryDate = "2033-12-31 23:59:59"

    init() {
        scanIDAApps()
        scanSurgeApps()
        audioManager.play()
        useCustomIcon = UserDefaults.standard.bool(forKey: "useCustomIcon")
        updateAppIcon()
    }
    
    private func updateAppIcon() {
        UserDefaults.standard.set(useCustomIcon, forKey: "useCustomIcon")
        if useCustomIcon {
            NSWorkspace.shared.setIcon(nil, forFile: Bundle.main.bundlePath)
            if !GIFDockAnimator.shared.isRunning {
                NSApp.applicationIconImage = nil
            }
        } else {
            if let icon = NSImage(named: "AppIcon") {
                NSWorkspace.shared.setIcon(icon, forFile: Bundle.main.bundlePath)
                if GIFDockAnimator.shared.isRunning {
                    GIFDockAnimator.shared.stop()
                } else {
                    NSApp.applicationIconImage = icon.asMacOSAppIcon()
                }
            } else {
                NSWorkspace.shared.setIcon(nil, forFile: Bundle.main.bundlePath)
                NSApp.applicationIconImage = nil
            }
        }
    }

    func scanIDAApps() {
        isProcessing = true
        logOutput = "正在扫描 IDA 应用..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = IDALocalizer.detectApps()
            let models = apps.map { info in
                IDAAppModel(
                    path: info.path,
                    version: info.version,
                    localizationStatus: info.isPatched ? "已安装汉化" : "未安装汉化",
                    activationStatus: info.isActivated ? "已激活" : "未激活"
                )
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.idaApps = models
                if !models.isEmpty && self.selectedApp == nil {
                    self.selectedApp = models[0]
                }
                self.logOutput += "\n✅ 找到 \(models.count) 个 IDA 应用"
                self.isProcessing = false
            }
        }
    }

    private func findIDAAppInfo(from model: IDAAppModel) -> IDAAppInfo? {
        let all = IDALocalizer.detectApps()
        return all.first { $0.path == model.path }
    }

    func installLocalization() {
        guard let app = selectedApp else { return }
        isProcessing = true
        logOutput = "正在为 \(app.displayName) 安装汉化..."
        let appPath = app.path
        
        DispatchQueue.global(qos: .userInitiated).async {
            let allApps = IDALocalizer.detectApps()
            let info = allApps.first { $0.path == appPath }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard let info = info else {
                    self.logOutput += "\n❌ 未找到对应 IDA 应用"
                    self.isProcessing = false
                    return
                }
                self.runLocalizationInstall(app: info)
            }
        }
    }
    
    private func runLocalizationInstall(app: IDAAppInfo) {
        DispatchQueue.global(qos: .userInitiated).async {
            IDALocalizer.install(app: app, progress: { msg in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.logOutput += "\n\(msg)"
                }
            }, completion: { success, message in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if success {
                        self.logOutput += "\n✅ 汉化安装成功\n\(message)"
                        self.showSuccess(title: "汉化安装成功", message: message)
                    } else {
                        self.logOutput += "\n❌ 安装失败\n\(message)"
                        self.showError(title: "安装失败", message: message)
                    }
                    self.scanIDAApps()
                }
            })
        }
    }

    func uninstallLocalization() {
        guard let app = selectedApp else { return }
        isProcessing = true
        logOutput = "正在为 \(app.displayName) 卸载汉化..."
        let appPath = app.path
        
        DispatchQueue.global(qos: .userInitiated).async {
            let allApps = IDALocalizer.detectApps()
            let info = allApps.first { $0.path == appPath }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard let info = info else {
                    self.logOutput += "\n❌ 未找到对应 IDA 应用"
                    self.isProcessing = false
                    return
                }
                self.runLocalizationUninstall(app: info)
            }
        }
    }
    
    private func runLocalizationUninstall(app: IDAAppInfo) {
        DispatchQueue.global(qos: .userInitiated).async {
            IDALocalizer.uninstall(app: app, progress: { msg in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.logOutput += "\n\(msg)"
                }
            }, completion: { success, message in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if success {
                        self.logOutput += "\n✅ 汉化已卸载\n\(message)"
                        self.showSuccess(title: "汉化已卸载", message: message)
                    } else {
                        self.logOutput += "\n❌ 卸载失败\n\(message)"
                        self.showError(title: "卸载失败", message: message)
                    }
                    self.scanIDAApps()
                }
            })
        }
    }

    func activate() {
        guard let app = selectedApp else { return }
        isProcessing = true
        logOutput = "正在激活 \(app.displayName)..."
        let appPath = app.path
        let name = userName
        let email = userEmail
        let expiry = expiryDate
        
        DispatchQueue.global(qos: .userInitiated).async {
            let allApps = IDALocalizer.detectApps()
            let info = allApps.first { $0.path == appPath }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard let info = info else {
                    self.logOutput += "\n❌ 未找到对应 IDA 应用"
                    self.isProcessing = false
                    return
                }
                self.runActivation(app: info, userName: name, userEmail: email, expiryDate: expiry)
            }
        }
    }
    
    private func runActivation(app: IDAAppInfo, userName: String, userEmail: String, expiryDate: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            IDAActivator.activate(
                app: app,
                userName: userName,
                userEmail: userEmail,
                expiryDate: expiryDate,
                progress: { msg in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.logOutput += "\n\(msg)"
                    }
                },
                completion: { success, message in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        if success {
                            self.logOutput += "\n✅ 激活成功\n\(message)"
                            self.showSuccess(title: "激活成功", message: message)
                        } else {
                            self.logOutput += "\n❌ 激活失败\n\(message)"
                            self.showError(title: "激活失败", message: message)
                        }
                        self.scanIDAApps()
                    }
                }
            )
        }
    }

    private func showSuccess(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    func scanSurgeApps() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = SurgeActivator.shared.detectApps()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.surgeApps = apps
                if !apps.isEmpty && self.selectedSurgeApp == nil {
                    self.selectedSurgeApp = apps[0]
                }
            }
        }
    }

    func activateSurge() {
        guard let app = selectedSurgeApp else { return }
        isSurgeProcessing = true
        surgeLogOutput = "正在激活 \(app.displayName)..."

        SurgeActivator.shared.activate(
            app: app,
            progress: { [weak self] msg in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.surgeLogOutput += "\n\(msg)"
                }
            },
            completion: { [weak self] success, message in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isSurgeProcessing = false
                    if success {
                        self.surgeLogOutput += "\n✅ 激活成功\n\(message)"
                    } else {
                        self.surgeLogOutput += "\n❌ 激活失败\n\(message)"
                        self.showError(title: "Surge 激活失败", message: message)
                    }
                    self.scanSurgeApps()
                }
            }
        )
    }
}
