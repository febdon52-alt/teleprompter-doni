import XCTest
@testable import BacaKamera

final class IdeaEngineTests: XCTestCase {
    func testBankLoads() {
        XCTAssertEqual(Bank.niches.count, 10)
        XCTAssertTrue(Bank.niches.allSatisfy { $0.tips.count == 6 && $0.tips.allSatisfy { $0.count == 3 } })
    }

    func testEveryNicheDurationAndPlatformProducesIdeasAndScripts() {
        for n in Bank.niches {
            for dur in [15, 30, 60, 180, 480] {
                for plat in ["short", "long"] {
                    var b = Brief()
                    b.niche = n.key
                    b.dur = dur
                    b.plat = plat
                    let ideas = IdeaEngine.offlineIdeas(b)
                    XCTAssertEqual(ideas.count, 5)
                    for idea in ideas {
                        XCTAssertFalse(idea.title.isEmpty)
                        XCTAssertFalse(idea.hook.isEmpty)
                        let s = IdeaEngine.offlineScript(idea)
                        XCTAssertTrue(s.contains("## HOOK"), s)
                        XCTAssertTrue(s.contains("## PENUTUP"), s)
                        XCTAssertFalse(s.contains("\n\n\n"))
                    }
                }
            }
        }
    }

    func testCustomTopicIsUsed() {
        var b = Brief()
        b.niche = "lain"
        b.topic = "budidaya cabai"
        let ideas = IdeaEngine.offlineIdeas(b)
        XCTAssertEqual(ideas.count, 5)
        let all = ideas.map { IdeaEngine.offlineScript($0) }.joined()
        XCTAssertTrue(all.contains("budidaya cabai"))
    }

    func testTopicOverridesActivity() {
        var b = Brief()
        b.niche = "bisnis"
        b.topic = "jualan kopi susu"
        let text = IdeaEngine.offlineIdeas(b).map { $0.title + $0.hook }.joined()
        XCTAssertTrue(text.contains("jualan kopi susu"))
    }

    func testLongerDurationGivesLongerScripts() {
        var short = Brief(); short.dur = 15
        var long = Brief(); long.dur = 480; long.plat = "long"
        let idea15 = IdeaEngine.offlineIdeas(short).first { $0.fmt == "tips" } ?? IdeaEngine.offlineIdeas(short)[0]
        let idea480 = IdeaEngine.offlineIdeas(long).first { $0.fmt == "tips" } ?? IdeaEngine.offlineIdeas(long)[0]
        XCTAssertGreaterThan(scriptWordCount(IdeaEngine.offlineScript(idea480)), scriptWordCount(IdeaEngine.offlineScript(idea15)))
    }

    func testStringHelpers() {
        XCTAssertEqual(IdeaEngine.cap("halo"), "Halo")
        XCTAssertEqual(IdeaEngine.lc("Halo dunia"), "halo dunia")
        XCTAssertEqual(IdeaEngine.lc("SEO penting"), "SEO penting")
        XCTAssertEqual(IdeaEngine.listJoin(["a", "b", "c"]), "a, b, dan c")
        XCTAssertEqual(IdeaEngine.listJoin(["a", "b"]), "a dan b")
        XCTAssertEqual(fmtTime(75), "01:15")
    }

    func testPromptParser() {
        let lines = PromptParser.parse("## HOOK\nHalo (senyum)\n\n(tatap kamera)\nIsi")
        XCTAssertEqual(lines, [.section("HOOK"), .text("Halo (senyum)"), .gap, .direction("(tatap kamera)"), .text("Isi")])
    }

    func testWordCountIgnoresHeadingsAndDirections() {
        XCTAssertEqual(scriptWordCount("## HOOK\nHalo semua (senyum lebar)\n(tatap)\nIni isi"), 4)
    }

    func testParseAIIdeas() {
        let reply = "Tentu!\n{\"ide\":[{\"judul\":\"Judul A\",\"hook\":\"Hook A\",\"sudut\":\"Tips\"},{\"judul\":\"\",\"hook\":\"x\"}]}"
        let ideas = IdeaEngine.parseIdeas(reply, brief: Brief())
        XCTAssertEqual(ideas.count, 1)
        XCTAssertEqual(ideas[0].title, "Judul A")
        XCTAssertTrue(ideas[0].fromAI)
        XCTAssertTrue(IdeaEngine.parseIdeas("bukan json", brief: Brief()).isEmpty)
    }

    func testPromptsMentionKeyFacts() {
        var b = Brief(); b.dur = 60
        let idea = IdeaEngine.offlineIdeas(b)[0]
        let p = IdeaEngine.scriptPrompt(idea)
        XCTAssertTrue(p.contains("150 kata"))
        XCTAssertTrue(p.contains("## HOOK"))
        XCTAssertTrue(IdeaEngine.ideaPrompt(b).contains("\"ide\""))
    }
}

final class StoreAndEngineTests: XCTestCase {
    func testStoreAddUpdateDelete() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("naskah-test-\(UUID().uuidString).json")
        let store = ScriptStore(url: url)
        XCTAssertTrue(store.scripts.isEmpty)
        let s = store.add(title: "A", body: "isi")
        store.update(s.id, title: "B", body: "baru")
        XCTAssertEqual(store.script(s.id)?.title, "B")
        store.saveNow()
        let reloaded = ScriptStore(url: url)
        XCTAssertEqual(reloaded.scripts.count, 1)
        XCTAssertEqual(reloaded.scripts[0].body, "baru")
        reloaded.delete(s.id)
        XCTAssertTrue(reloaded.scripts.isEmpty)
        try? FileManager.default.removeItem(at: url)
    }

    func testScrollEngineClampsAndRewinds() {
        let e = ScrollEngine()
        e.maxOffset = 100
        e.scroll(to: 500)
        XCTAssertEqual(e.offset, 100)
        e.scroll(to: -20)
        XCTAssertEqual(e.offset, 0)
        e.offset = 50
        e.rewind()
        XCTAssertEqual(e.offset, 0)
        e.speed = 5; e.fontSize = 40
        XCTAssertEqual(Double(e.pixelsPerSecond), 5 * 0.1 * 40 * 1.36, accuracy: 0.001)
    }

    func testVideoRatioValues() {
        XCTAssertEqual(VideoRatio.allCases.map { $0.rawValue }, ["9:16", "3:4"])
    }
}
