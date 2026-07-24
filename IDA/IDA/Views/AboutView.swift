import SwiftUI

struct AboutView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
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
                            .frame(width: 100, height: 100)
                            .opacity(0.2)

                        IDAColorfulIcon(systemName: "hammer.fill", size: 48)
                    }
                    .frame(width: 100, height: 100)

                    Text("IDA 汉化工具")
                        .font(.system(size: 28, weight: .bold))
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 16) {
                    Text("图标设置")
                        .font(.system(size: 16, weight: .semibold))
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            ZStack {
                                if let iconImage = NSImage(named: "AppIcon") {
                                    Image(nsImage: iconImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 64, height: 64)
                                }
                                
                                if !appState.useCustomIcon {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accentColor, lineWidth: 2)
                                        .frame(width: 64, height: 64)
                                }
                            }
                            .frame(width: 64, height: 64)
                            .onTapGesture {
                                appState.useCustomIcon = false
                            }
                            
                            Text("哈基米")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            ZStack {
                                if let iconImage = NSImage(named: "IDAAppIcon") {
                                    Image(nsImage: iconImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 64, height: 64)
                                }
                                
                                if appState.useCustomIcon {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accentColor, lineWidth: 2)
                                        .frame(width: 64, height: 64)
                                }
                            }
                            .frame(width: 64, height: 64)
                            .onTapGesture {
                                appState.useCustomIcon = true
                            }
                            
                            Text("IDA")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
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
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 480, alignment: .leading)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
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
                                    .frame(width: 36, height: 36)
                                    .opacity(0.15)

                                IDAColorfulIcon(systemName: "person.fill", size: 16)
                            }
                            .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("有问题？")
                                    .font(.system(size: 14, weight: .semibold))

                                Text("@pxx917144686")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                        Link(destination: URL(string: "https://github.com/pxx917144686")!) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
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
                                        .frame(width: 36, height: 36)
                                        .opacity(0.15)

                                    IDAColorfulIcon(systemName: "link", size: 16)
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("APP图形界面与操作逻辑代码实现")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("https://github.com/pxx917144686")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor)
                                }

                                Spacer()

                                IDAColorfulIcon(systemName: "arrow.up.right.square", size: 14)
                            }
                        }
                        
                        Link(destination: URL(string: "https://github.com/Mac-XK")!) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
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
                                        .frame(width: 36, height: 36)
                                        .opacity(0.15)

                                    IDAColorfulIcon(systemName: "link", size: 16)
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("汉化字符串文件提供")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("https://github.com/Mac-XK")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor)
                                }

                                Spacer()

                                IDAColorfulIcon(systemName: "arrow.up.right.square", size: 14)
                            }
                        }
                        
                        Link(destination: URL(string: "https://docs.hex-rays.com/release-notes/9_4")!) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
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
                                        .frame(width: 36, height: 36)
                                        .opacity(0.15)

                                    IDAColorfulIcon(systemName: "book.fill", size: 16)
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("IDA 9.4 官方文档")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("docs.hex-rays.com/release-notes/9_4")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor)
                                }

                                Spacer()

                                IDAColorfulIcon(systemName: "arrow.up.right.square", size: 14)
                            }
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 480)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
        }
    }
}
