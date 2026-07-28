import SwiftUI

@main
struct IDAApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("工具") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
