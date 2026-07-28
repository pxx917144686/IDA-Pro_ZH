import SwiftUI

struct SurgeActivationView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        IDAColorfulIcon(systemName: "bolt.shield.fill", size: 24)
                        Text("Surge Mac 激活")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)
                    }

                    Text("激活 Surge Mac")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                if let selectedSurge = appState.selectedSurgeApp {
                    SurgeSelectionCard(app: selectedSurge)
                } else {
                    NoSurgeCard()
                }

                if appState.selectedSurgeApp != nil {
                    Button {
                        appState.activateSurge()
                    } label: {
                        HStack(spacing: 8) {
                            IDAColorfulIcon(systemName: "bolt.fill", size: 14)
                            Text(appState.isSurgeProcessing ? "激活中..." : "立即激活")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.5, blue: 1.0),
                                    Color(red: 0.4, green: 0.3, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isSurgeProcessing || appState.selectedSurgeApp == nil)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            IDAColorfulIcon(systemName: "terminal.fill", size: 14)
                            Text("执行日志")
                                .font(.system(size: 14, weight: .semibold))
                        }

                        ScrollView {
                            Text(appState.surgeLogOutput.isEmpty ? "等待操作..." : appState.surgeLogOutput)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .frame(height: 240)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(28)
        }
    }
}

struct SurgeSelectionCard: View {
    let app: SurgeAppInfo

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName)
                    .font(.system(size: 16, weight: .semibold))

                HStack(spacing: 8) {
                    if app.activationStatus == .activated {
                        statusBadge(for: app.activationStatus)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("路径")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text((app.path as NSString).lastPathComponent)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
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
    }

    private func statusBadge(for status: SurgeActivationStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(for: status))
                .frame(width: 6, height: 6)
            Text(statusText(for: status))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor(for: status))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(statusColor(for: status).opacity(0.1))
        )
    }

    private func statusColor(for status: SurgeActivationStatus) -> Color {
        switch status {
        case .activated: return .green
        case .notActivated: return .orange
        case .failed: return .red
        default: return .gray
        }
    }

    private func statusText(for status: SurgeActivationStatus) -> String {
        switch status {
        case .activated: return "已激活"
        case .notActivated: return "未激活"
        case .failed: return "激活失败"
        default: return "未知"
        }
    }
}

struct NoSurgeCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("未检测到 Surge")
                    .font(.system(size: 16, weight: .semibold))
                Text("请确保 Surge 已安装到 /Applications 目录")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
