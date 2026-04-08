import SwiftUI

@main
struct DriveIconGuardViewerApp: App {
    var body: some Scene {
        WindowGroup("Google Drive Icon Guard") {
            ScopeInventoryWindow()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutWindowMenuButton()
            }
        }

        Window("About Google Drive Icon Guard", id: "about-google-drive-icon-guard") {
            AboutWindow()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 520)
    }
}

private struct AboutWindowMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About Google Drive Icon Guard") {
            openWindow(id: "about-google-drive-icon-guard")
        }
    }
}
