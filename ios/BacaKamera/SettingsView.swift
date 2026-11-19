import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: ScriptStore
    @State private var confirmWipe = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Pakai Claude untuk ide dan naskah", isOn: $settings.useAI)
                    SecureField("API key Anthropic (sk-ant-…)", text: $settings.apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Picker("Model", selection: $settings.model) {
                        ForEach(AppSettings.models, id: \.0) { Text($0.1).tag($0.0) }
                    }
                } header: {
                    Text("Ide dan naskah AI")
                } footer: {
                    Text("Kunci disimpan di Keychain iPhone dan hanya dikirim ke Anthropic. Tanpa kunci, aplikasi memakai bank ide bawaan yang bekerja tanpa internet.")
                }

                Section("Teleprompter") {
                    VStack(alignment: .leading) {
                        Text("Kecepatan awal: \(Int(settings.speed))")
                        Slider(value: $settings.speed, in: 1...15, step: 0.5)
                    }
                    VStack(alignment: .leading) {
                        Text("Ukuran huruf: \(Int(settings.fontSize))")
                        Slider(value: $settings.fontSize, in: 24...80, step: 2)
                    }
                    Picker("Hitung mundur", selection: $settings.countdown) {
                        Text("Tidak ada").tag(0)
                        Text("3 detik").tag(3)
                        Text("5 detik").tag(5)
                    }
                    Toggle("Teks rata tengah", isOn: $settings.centerText)
                    Toggle("Cermin (untuk kaca teleprompter)", isOn: $settings.mirrorText)
                }

                Section {
                    Picker("Rasio video", selection: $settings.ratio) {
                        ForEach(VideoRatio.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Cerminkan hasil rekaman", isOn: $settings.mirrorRecording)
                } header: {
                    Text("Kamera")
                } footer: {
                    Text("9:16 memenuhi layar vertikal (TikTok, Reels, Shorts). 3:4 memakai bidang pandang sensor yang lebih lebar. Zoom diatur dengan slider atau cubit layar saat membaca. Video direkam 1080p, 30 fps, lalu disimpan ke app Foto.")
                }

                Section("Data") {
                    Button("Hapus semua naskah", role: .destructive) { confirmWipe = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ink.ignoresSafeArea())
            .navigationTitle("Atur")
            .confirmationDialog("Hapus semua naskah?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Hapus semua", role: .destructive) { store.deleteAll() }
                Button("Batal", role: .cancel) {}
            }
        }
    }
}
