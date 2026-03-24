import SwiftUI

@main
struct DriveIconGuardViewerApp: App {
    var body: some Scene {
        WindowGroup("Google Drive Icon Guard") {
            ScopeInventoryWindow()
        }
        .windowResizability(.contentSize)
    }
}
