import SwiftUI

struct LocalizationView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        IDAColorfulIcon(systemName: "globe", size: 24)
                        Text("汉化管理")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)
                    }

                    Text("安装或卸载 IDA 的中文汉化补丁")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                if let selectedApp = appState.selectedApp {
                    IDASelectionCard(app: selectedApp)
                } else {
                    NoIDACard()
                }

                if let app = appState.selectedApp {
                    HStack(spacing: 16) {
                        if app.localizationStatus == "已安装汉化" {
                            Button {
                                appState.uninstallLocalization()
                            } label: {
                                HStack(spacing: 8) {
                                    IDAColorfulIcon(systemName: "trash.circle.fill", size: 14)
                                    Text("卸载汉化")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.red.opacity(0.1))
                                )
                                .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(appState.isProcessing)
                        } else {
                            Button {
                                appState.installLocalization()
                            } label: {
                                HStack(spacing: 8) {
                                    IDAColorfulIcon(systemName: "arrow.down.circle.fill", size: 14)
                                    Text("安装汉化")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.3, blue: 0.3),
                                            Color(red: 1.0, green: 0.6, blue: 0.1),
                                            Color(red: 0.3, green: 0.6, blue: 1.0),
                                            Color(red: 0.7, green: 0.3, blue: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .disabled(appState.isProcessing)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        IDAColorfulIcon(systemName: "terminal.fill", size: 14)
                        Text("运行日志")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    ScrollView {
                        Text(appState.logOutput.isEmpty ? "等待操作..." : appState.logOutput)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(28)
        }
    }
}

struct IDASelectionCard: View {
    let app: IDAAppModel
    @State private var iconImage: NSImage?

    var body: some View {
        HStack(spacing: 16) {

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.2, blue: 0.2),
                                Color(red: 1.0, green: 0.6, blue: 0.0),
                                Color(red: 0.2, green: 0.5, blue: 1.0),
                                Color(red: 0.7, green: 0.3, blue: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .opacity(0.2)

                if let image = iconImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .cornerRadius(10)
                } else {
                    IDAColorfulIcon(systemName: "app.fill", size: 28)
                }
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                Text(app.displayName)
                    .font(.system(size: 18, weight: .bold))

                Text(app.path)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    StatusBadge(text: app.localizationStatus, isActive: app.localizationStatus == "已安装汉化", color: .blue)
                    StatusBadge(text: app.activationStatus, isActive: app.activationStatus == "已激活", color: .green)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            loadIcon()
        }
    }

    private func loadIcon() {
        let workspace = NSWorkspace.shared
        iconImage = workspace.icon(forFile: app.path)
    }
}

struct NoIDACard: View {
    var body: some View {
        VStack(spacing: 12) {
            IDAColorfulIcon(systemName: "exclamationmark.triangle", size: 36)

            Text("未选择 IDA 应用")
                .font(.system(size: 16, weight: .semibold))

            Text("请从左侧列表中选择一个 IDA 应用")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}

struct StatusBadge: View {
    let text: String
    let isActive: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? color : .secondary)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isActive ? color.opacity(0.15) : Color.secondary.opacity(0.1))
        )
        .foregroundColor(isActive ? color : .secondary)
    }
}
