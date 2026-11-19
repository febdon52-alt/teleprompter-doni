import SwiftUI

struct ScriptsView: View {
    @EnvironmentObject private var store: ScriptStore
    @State private var path: [UUID] = []

    private var sorted: [Script] { store.scripts.sorted { $0.updated > $1.updated } }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.scripts.isEmpty {
                    VStack(spacing: 8) {
                        Text("Belum ada naskah").font(.headline)
                        Text("Ambil ide di tab Ide, atau ketuk + untuk menulis sendiri.")
                            .foregroundColor(Theme.muted).multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    List {
                        ForEach(sorted) { s in
                            NavigationLink(value: s.id) { row(s) }
                                .listRowBackground(Theme.panel)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { sorted[$0].id }
                            ids.forEach { store.delete($0) }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.ink.ignoresSafeArea())
            .navigationTitle("Naskah")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let s = store.add(title: "", body: "")
                        path = [s.id]
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Naskah baru")
                }
            }
            .navigationDestination(for: UUID.self) { id in ScriptEditorView(id: id) }
        }
        .onReceive(store.$pendingOpen.compactMap { $0 }) { id in
            path = [id]
            store.pendingOpen = nil
        }
    }

    private func row(_ s: Script) -> some View {
        let words = scriptWordCount(s.body)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(s.title.isEmpty ? "Tanpa judul" : s.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                if s.example {
                    Text("CONTOH").font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundColor(Theme.cue)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.cue.opacity(0.5)))
                }
            }
            Text("\(words) kata · ≈ \(fmtTime(Double(words) / wordsPerSecond))")
                .font(.system(size: 12, design: .monospaced)).foregroundColor(Theme.muted)
        }
    }
}

struct ScriptEditorView: View {
    let id: UUID

    @EnvironmentObject private var store: ScriptStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var text = ""
    @State private var loaded = false
    @State private var reading = false
    @State private var regenerating = false
    @State private var confirmDelete = false
    @State private var note: String?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Judul video", text: $title)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(12)
                    .background(Theme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    let w = scriptWordCount(text)
                    Text("\(w) kata · ≈ \(fmtTime(Double(w) / wordsPerSecond))")
                        .font(.system(size: 12, design: .monospaced)).foregroundColor(Theme.muted)
                    Spacer()
                    if regenerating { ProgressView() }
                }

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 340)
                    .background(Theme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(regenerating)

                Text("## HOOK jadi penanda bagian. Teks dalam (kurung) jadi arahan kecil yang tidak perlu dibaca.")
                    .font(.footnote).foregroundColor(Theme.muted)

                if let n = note { Text(n).font(.footnote).foregroundColor(Theme.cue) }

                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    reading = true
                } label: { Label("Mulai baca", systemImage: "play.fill") }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || regenerating)

                HStack(spacing: 10) {
                    if store.script(id)?.idea != nil {
                        Button("Tulis ulang") { regenerate() }.buttonStyle(SecondaryButtonStyle()).disabled(regenerating)
                    }
                    Button(copied ? "Tersalin" : "Salin") {
                        UIPasteboard.general.string = text
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button("Hapus") { confirmDelete = true }.buttonStyle(SecondaryButtonStyle(danger: true))
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.ink.ignoresSafeArea())
        .navigationTitle("Naskah")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded, let s = store.script(id) else { return }
            title = s.title
            text = s.body
            loaded = true
        }
        .onChange(of: title) { v in if loaded { store.update(id, title: v) } }
        .onChange(of: text) { v in if loaded { store.update(id, body: v) } }
        .fullScreenCover(isPresented: $reading) {
            TeleprompterView(text: text).environmentObject(settings)
        }
        .confirmationDialog("Hapus naskah ini?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Hapus", role: .destructive) {
                store.delete(id)
                dismiss()
            }
            Button("Batal", role: .cancel) {}
        }
    }

    private func regenerate() {
        guard let idea = store.script(id)?.idea else { return }
        note = nil
        let useAI = settings.aiReady
        let client = ClaudeClient(apiKey: settings.apiKey, model: settings.model)
        regenerating = true
        Task { @MainActor in
            if useAI {
                do { text = try await client.script(idea) }
                catch {
                    note = error.localizedDescription + " Memakai naskah bawaan."
                    text = IdeaEngine.offlineScript(idea)
                }
            } else {
                text = IdeaEngine.offlineScript(idea)
            }
            regenerating = false
        }
    }
}
