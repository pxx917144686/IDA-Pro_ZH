import SwiftUI

struct AboutView: View {
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
                                    Text("github")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text("https://github.com/pxx917144686")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor)
                                    Text("https://github.com/Mac-XK")
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
