import SwiftUI

struct IdeasView: View {
    var onOpened: () -> Void

    @EnvironmentObject private var store: ScriptStore
    @EnvironmentObject private var settings: AppSettings
    @AppStorage("brief.niche") private var niche = "bisnis"
    @AppStorage("brief.topic") private var topic = ""
    @AppStorage("brief.plat") private var plat = "short"
    @AppStorage("brief.dur") private var dur = 60
    @AppStorage("brief.tone") private var tone = "santai"

    @State private var ideas: [Idea] = []
    @State private var loading = false
    @State private var writingID: UUID?
    @State private var message: String?

    private var brief: Brief { Brief(niche: niche, topic: topic, plat: plat, dur: dur, tone: tone) }

    private var nicheItems: [(String, String)] { Bank.niches.map { ($0.key, $0.label) } + [("lain", "Lainnya")] }
    private var durItems: [(String, String)] {
        IdeaEngine.durs.filter { plat == "long" ? $0.0 >= 180 : $0.0 <= 180 }.map { (String($0.0), $0.1) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cari ide, dapat naskah, langsung baca.")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text("Pilih niche dan gaya, ketuk satu ide, lalu naskahnya siap dibaca di teleprompter.")
                        .foregroundColor(Theme.muted)
                }

                section("NICHE") { ChipGrid(items: nicheItems, selection: $niche) }

                section("TOPIK SPESIFIK (OPSIONAL)") {
                    TextField("mis. jualan kopi susu, skincare remaja", text: $topic)
                        .padding(12)
                        .background(Theme.panel)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                section("PLATFORM") { ChipGrid(items: IdeaEngine.plats, selection: $plat) }
                section("DURASI") {
                    ChipGrid(items: durItems, selection: Binding(get: { String(dur) }, set: { dur = Int($0) ?? 60 }))
                }
                section("GAYA BICARA") { ChipGrid(items: IdeaEngine.tones.map { ($0.key, $0.label) }, selection: $tone) }

                Button(action: generate) {
                    if loading {
                        HStack(spacing: 8) { ProgressView().tint(Theme.cueInk); Text("Claude sedang mencari ide…") }
                    } else {
                        Text("Beri 5 ide")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(loading)

                if let m = message {
                    Text(m).font(.footnote).foregroundColor(Theme.cue)
                }

                VStack(spacing: 12) {
                    ForEach(ideas) { idea in ideaCard(idea) }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.ink.ignoresSafeArea())
        .onAppear { if ideas.isEmpty { ideas = IdeaEngine.offlineIdeas(brief) } }
        .onChange(of: plat) { p in
            if p == "long" && dur < 180 { dur = 480 }
            if p == "short" && dur > 180 { dur = 60 }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(1.5).foregroundColor(Theme.muted)
            content()
        }
    }

    private func ideaCard(_ idea: Idea) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text((idea.label + (idea.fromAI ? " · Claude" : "")).uppercased())
                .font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(1.5).foregroundColor(Theme.cue)
            Text(idea.title).font(.system(size: 19, weight: .heavy, design: .rounded))
            Text("“\(idea.hook)”")
                .foregroundColor(Color(white: 0.8))
                .padding(.leading, 10)
                .overlay(Rectangle().fill(Theme.line).frame(width: 2), alignment: .leading)
            HStack {
                Text("≈ \(idea.brief.dur >= 60 ? "\(idea.brief.dur / 60) mnt" : "\(idea.brief.dur) dtk") · \(IdeaEngine.platLabel(idea.brief.plat))")
                    .font(.system(size: 12, design: .monospaced)).foregroundColor(Theme.muted)
                Spacer()
                Button { write(idea) } label: {
                    if writingID == idea.id {
                        HStack(spacing: 6) { ProgressView(); Text("Menulis…") }
                    } else {
                        Text("Tulis naskah →")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(writingID != nil)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Aksi

    private func generate() {
        let b = brief
        message = nil
        guard settings.aiReady else {
            ideas = IdeaEngine.offlineIdeas(b)
            return
        }
        loading = true
        let client = ClaudeClient(apiKey: settings.apiKey, model: settings.model)
        Task { @MainActor in
            do {
                ideas = try await client.ideas(b)
            } catch {
                message = error.localizedDescription + " Memakai ide bawaan."
                ideas = IdeaEngine.offlineIdeas(b)
            }
            loading = false
        }
    }

    private func write(_ idea: Idea) {
        writingID = idea.id
        message = nil
        let client = ClaudeClient(apiKey: settings.apiKey, model: settings.model)
        let useAI = settings.aiReady
        Task { @MainActor in
            var body = ""
            if useAI {
                do { body = try await client.script(idea) }
                catch {
                    message = error.localizedDescription + " Memakai naskah bawaan."
                    body = IdeaEngine.offlineScript(idea)
                }
            } else {
                body = IdeaEngine.offlineScript(idea)
            }
            let s = store.add(title: idea.title, body: body, idea: idea)
            writingID = nil
            store.pendingOpen = s.id
            onOpened()
        }
    }
}
