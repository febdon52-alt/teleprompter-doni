import Foundation
import Combine

struct Brief: Codable, Hashable {
    var niche: String = "bisnis"
    var topic: String = ""
    var plat: String = "short"
    var dur: Int = 60
    var tone: String = "santai"
}

struct Idea: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var hook: String
    var fmt: String
    var label: String
    var tipIdx: [Int] = []
    var brief: Brief
    var fromAI = false
}

struct Script: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var body: String
    var updated = Date()
    var idea: Idea?
    var example = false

    static func == (a: Script, b: Script) -> Bool { a.id == b.id && a.updated == b.updated }
}

final class ScriptStore: ObservableObject {
    @Published var scripts: [Script] = []
    @Published var pendingOpen: UUID?

    private let url: URL
    private var saveWork: DispatchWorkItem?

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("naskah.json")
        load()
        if scripts.isEmpty && url == nil && !UserDefaults.standard.bool(forKey: "seeded") {
            seedExample()
            UserDefaults.standard.set(true, forKey: "seeded")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Script].self, from: data) else { return }
        scripts = list
    }

    func saveNow() {
        saveWork?.cancel()
        if let data = try? JSONEncoder().encode(scripts) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func saveSoon() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func script(_ id: UUID) -> Script? { scripts.first { $0.id == id } }

    @discardableResult
    func add(title: String, body: String, idea: Idea? = nil, example: Bool = false) -> Script {
        let s = Script(title: title, body: body, updated: Date(), idea: idea, example: example)
        scripts.append(s)
        saveNow()
        return s
    }

    func update(_ id: UUID, title: String? = nil, body: String? = nil) {
        guard let i = scripts.firstIndex(where: { $0.id == id }) else { return }
        if let t = title { scripts[i].title = t }
        if let b = body { scripts[i].body = b }
        scripts[i].updated = Date()
        saveSoon()
    }

    func delete(_ id: UUID) {
        scripts.removeAll { $0.id == id }
        saveNow()
    }

    func deleteAll() {
        scripts.removeAll()
        saveNow()
    }

    private func seedExample() {
        var b = Brief()
        b.niche = "bisnis"
        let idea = IdeaEngine.offlineIdeas(b).first { $0.fmt == "salah" } ?? IdeaEngine.offlineIdeas(b)[0]
        add(title: idea.title, body: IdeaEngine.offlineScript(idea), idea: idea, example: true)
    }
}

/// Menghitung kata naskah tanpa judul bagian dan arahan dalam kurung.
func scriptWordCount(_ s: String) -> Int {
    let noHeads = s.replacingOccurrences(of: "(?m)^##.*$", with: "", options: .regularExpression)
    let noDirs = noHeads.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
    return noDirs.split(whereSeparator: { $0.isWhitespace }).count
}

let wordsPerSecond = 2.5  // sekitar 150 kata per menit
