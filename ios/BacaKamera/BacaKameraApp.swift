import SwiftUI

@main
struct BacaKameraApp: App {
    @StateObject private var store = ScriptStore()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .preferredColorScheme(.dark)
        }
    }
}
