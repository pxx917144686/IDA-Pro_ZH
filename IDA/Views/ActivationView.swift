import SwiftUI

struct ActivationView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        IDAColorfulIcon(systemName: "key.fill", size: 24)
                        Text("IDA pro9.4激活")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)
                    }

                    Text("生成并激活 IDA Pro 许可证")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                if let selectedApp = appState.selectedApp {
                    IDASelectionCard(app: selectedApp)
                } else {
                    NoIDACard()
                }

                if appState.selectedApp != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("激活配置")
                            .font(.system(size: 16, weight: .semibold))

                        VStack(spacing: 12) {
                            FormField(label: "用户名", value: $appState.userName, icon: "person.fill")
                            FormField(label: "邮箱地址", value: $appState.userEmail, icon: "envelope.fill")
                            FormField(label: "到期日期", value: $appState.expiryDate, icon: "calendar")
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

                    Button {
                        appState.activate()
                    } label: {
                        HStack(spacing: 8) {
                            IDAColorfulIcon(systemName: "key.fill", size: 14)
                            Text("开始激活")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
                    .disabled(appState.isProcessing || appState.selectedApp == nil)
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

struct FormField: View {
    let label: String
    @Binding var value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            IDAColorfulIcon(systemName: icon, size: 14)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                TextField("", text: $value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
