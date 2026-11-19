import SwiftUI

struct RootView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            IdeasView(onOpened: { tab = 1 })
                .tabItem { Label("Ide", systemImage: "lightbulb") }
                .tag(0)
            ScriptsView()
                .tabItem { Label("Naskah", systemImage: "doc.text") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Atur", systemImage: "slider.horizontal.3") }
                .tag(2)
        }
        .tint(Theme.cue)
    }
}
