import SwiftUI

@main
struct IDAApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("工具") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 800)
                
                .onAppear {
                    if appState.useCustomIcon {
                        GIFDockAnimator.shared.start()
                    }
                }
                
                .onChange(of: appState.useCustomIcon) { enabled in
                    if enabled {
                        GIFDockAnimator.shared.start()
                    } else {
                        GIFDockAnimator.shared.stop()
                    }
                }
                
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    GIFDockAnimator.shared.stop()
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
