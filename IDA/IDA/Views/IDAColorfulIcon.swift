import SwiftUI

struct IDAColorfulIcon: View {
    let systemName: String
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.2, blue: 0.2),
                        Color(red: 1.0, green: 0.6, blue: 0.0),
                        Color(red: 1.0, green: 0.9, blue: 0.0),
                        Color(red: 0.2, green: 0.8, blue: 0.4),
                        Color(red: 0.2, green: 0.5, blue: 1.0),
                        Color(red: 0.7, green: 0.3, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
