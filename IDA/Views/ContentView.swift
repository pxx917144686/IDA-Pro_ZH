import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            DetailView()
        }
        .alert(appState.alertTitle, isPresented: $appState.showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(appState.alertMessage)
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var pulsePhase = 0.0

    private let pulseAnimation = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)

    var body: some View {
        List(selection: $appState.currentSection) {
            Section("功能") {
                ForEach(AppSection.allCases) { section in
                    NavigationLink(value: section) {
                        HStack(spacing: 10) {
                            IDAColorfulIcon(systemName: section.icon, size: 14)
                                .frame(width: 20, height: 20)
                            Text(section.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("检测到的 IDA") {
                if appState.idaApps.isEmpty {
                    Text("未检测到 IDA")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                        .padding(.vertical, 8)
                } else {
                    ForEach(appState.idaApps) { app in
                        Button {
                            appState.selectedApp = app
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                ZStack {
                                    if appState.audioManager.isPlaying {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                AngularGradient(
                                                    gradient: Gradient(colors: [
                                                        .red, .orange, .yellow, .green, .blue, .purple, .red
                                                    ]),
                                                    center: .center
                                                )
                                            )
                                            .frame(width: 40, height: 40)
                                            .blur(radius: 6)
                                            .opacity(0.6 + 0.4 * sin(pulsePhase * .pi * 2))
                                    }

                                    AppIconView(appPath: app.path)
                                        .frame(width: 36, height: 36)
                                        .cornerRadius(7)
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)

                                    HStack {
                                        if app.localizationStatus == "已安装汉化" {
                                            Text("✓ 已汉化")
                                                .font(.system(size: 11))
                                                .foregroundColor(.green)
                                        } else {
                                            Text("未汉化")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }

                                        if app.activationStatus == "已激活" {
                                            Text("✓ 已激活")
                                                .font(.system(size: 11))
                                                .foregroundColor(.green)
                                        }
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(appState.selectedApp?.id == app.id ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    appState.scanIDAApps()
                } label: {
                    HStack(spacing: 6) {
                        IDAColorfulIcon(systemName: "arrow.clockwise", size: 12)
                        Text("重新扫描")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.top, 4)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("IDA 工具箱")
        .onAppear {
            startPulseAnimation()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.audioManager.toggle()
                } label: {
                    IDAColorfulIcon(systemName: appState.audioManager.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill", size: 14)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.scanIDAApps()
                } label: {
                    IDAColorfulIcon(systemName: "arrow.clockwise", size: 14)
                }
                .disabled(appState.isProcessing)
            }
        }
    }

    private func startPulseAnimation() {
        withAnimation(pulseAnimation) {
            pulsePhase = 1.0
        }
    }
}

struct AppIconView: View {
    let appPath: String
    @State private var iconImage: NSImage?

    var body: some View {
        Group {
            if let image = iconImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
            }
        }
        .onAppear {
            loadIcon()
        }
        .onChange(of: appPath) { _ in
            loadIcon()
        }
    }

    private func loadIcon() {
        let workspace = NSWorkspace.shared
        iconImage = workspace.icon(forFile: appPath)
    }
}

struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.currentSection {
            case .localization:
                LocalizationView()
            case .translation:
                TranslationView()
            case .activation:
                ActivationView()
            case .about:
                AboutView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
