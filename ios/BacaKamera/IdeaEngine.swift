import Foundation

struct Niche: Codable {
    let key: String
    let label: String
    let audience: String
    let activity: String
    let goal: String
    let problem: String
    let past: String
    let win: String
    let tips: [[String]]   // [judul, penjelasan, kesalahan umum]
}

enum Bank {
    static let niches: [Niche] = {
        guard let url = Bundle.main.url(forResource: "bank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Niche].self, from: data) else { return [] }
        return list
    }()
}

struct Tone {
    let key: String
    let label: String
    let pre: [String]
    let cta: String
}

/// Konteks yang sudah diselesaikan dari niche + topik.
struct NicheContext {
    let label: String
    let audience: String
    let activity: String
    let goal: String
    let problem: String
    let past: String
    let win: String
    let tips: [[String]]
}

private struct FormatCtx {
    let c: NicheContext
    let n: Int
    let nw: String
    let tip2: String
}

private struct FormatDef {
    let key: String
    let label: String
    let many: Int?
    let titles: [(FormatCtx) -> String]
    let hooks: [(FormatCtx) -> String]
}

enum IdeaEngine {
    static let plats: [(String, String)] = [("short", "TikTok / Reels / Shorts"), ("long", "YouTube panjang")]
    static let durs: [(Int, String)] = [(15, "15 dtk"), (30, "30 dtk"), (60, "60 dtk"), (180, "3 mnt"), (480, "8 mnt")]

    static let tones: [Tone] = [
        Tone(key: "santai", label: "Santai", pre: ["", "", "Jujur ya, "], cta: "Simpan video ini biar nggak lupa, dan follow buat tips berikutnya."),
        Tone(key: "edukatif", label: "Edukatif", pre: ["", "Tahukah kamu? "], cta: "Simpan video ini sebagai catatan, dan bagikan ke teman yang butuh."),
        Tone(key: "cerita", label: "Storytelling", pre: [""], cta: "Kalau ini relate sama kamu, follow untuk cerita berikutnya."),
        Tone(key: "lucu", label: "Lucu", pre: ["Oke, jujur-jujuran aja. ", ""], cta: "Follow sebelum algoritma memisahkan kita."),
        Tone(key: "inspiratif", label: "Inspiratif", pre: ["Dengarkan ini baik-baik. ", ""], cta: "Kirim video ini ke satu orang yang perlu mendengarnya hari ini."),
        Tone(key: "jualan", label: "Soft selling", pre: [""], cta: "Kalau kamu mau panduan lengkapnya, cek link di bio, ya.")
    ]

    static let bridges = [
        "Kedengarannya sederhana, tapi justru di sini banyak orang menyerah.",
        "Coba praktikkan minggu ini, lalu lihat bedanya.",
        "Ini kelihatan kecil, tapi dampaknya terasa kalau dilakukan rutin.",
        "Banyak yang tahu soal ini, tapi sedikit yang benar-benar melakukannya.",
        "Kalau kamu baru bisa satu hal, mulai dari yang ini.",
        "Jangan dilewati, karena poin ini sering jadi pembeda."
    ]

    static let numWords = ["nol", "satu", "dua", "tiga", "empat", "lima", "enam", "tujuh"]
    static let ordinals = ["pertama", "kedua", "ketiga", "keempat", "kelima", "keenam", "ketujuh"]
    static let tipsPerDuration: [Int: Int] = [15: 1, 30: 2, 60: 3, 180: 5, 480: 6]

    private static let formats: [FormatDef] = [
        FormatDef(key: "tips", label: "Tips", many: nil,
                  titles: [{ "\($0.n) cara \($0.c.goal) tanpa ribet" }, { "\($0.n) trik \($0.c.activity) yang jarang dibahas" }],
                  hooks: [{ "Kalau kamu pengin \($0.c.goal), coba \($0.nw) hal ini." },
                          { "Ini \($0.nw) trik \($0.c.activity) yang jarang dibahas. Yang terakhir paling sering dilupakan." }]),
        FormatDef(key: "salah", label: "Kesalahan umum", many: nil,
                  titles: [{ "\($0.n) kesalahan \($0.c.activity) yang bikin \($0.c.problem)" }],
                  hooks: [{ "Stop dulu. Kalau \($0.c.problem), bisa jadi kamu melakukan salah satu dari \($0.nw) kesalahan ini." },
                          { "Aku dulu juga begini. Ini \($0.nw) kesalahan \($0.c.activity) yang bikin \($0.c.problem)." }]),
        FormatDef(key: "cerita", label: "Cerita pribadi", many: 2,
                  titles: [{ "Satu perubahan kecil yang bikin \($0.c.win)" }],
                  hooks: [{ "\($0.c.past) Sekarang \($0.c.win). Ini yang aku ubah." }]),
        FormatDef(key: "satu", label: "Satu hal penting", many: 2,
                  titles: [{ "Kalau cuma boleh satu hal untuk \($0.c.goal), lakukan ini" }],
                  hooks: [{ "Kalau aku cuma boleh kasih satu saran untuk \($0.c.goal), ini dia." }]),
        FormatDef(key: "pemula", label: "Untuk pemula", many: nil,
                  titles: [{ "Panduan \($0.c.activity) untuk pemula: \($0.n) langkah awal" }],
                  hooks: [{ "Baru mulai \($0.c.activity)? Ini \($0.nw) hal yang perlu kamu tahu duluan." }]),
        FormatDef(key: "opini", label: "Opini tidak populer", many: nil,
                  titles: [{ "Pendapat tidak populer soal \($0.c.activity)" }],
                  hooks: [{ "Pendapat tidak populer: \($0.tip2) adalah alasan terbesar \($0.c.problem)." }]),
        FormatDef(key: "tantangan", label: "Tantangan 7 hari", many: nil,
                  titles: [{ "Tantangan 7 hari untuk \($0.c.goal)" }],
                  hooks: [{ _ in "Ikut tantangan tujuh hari ini. Di hari ketujuh, kamu bakal merasakan bedanya." }])
    ]

    // MARK: - Teks

    static func cap(_ s: String) -> String {
        guard let f = s.first else { return s }
        return String(f).uppercased() + s.dropFirst()
    }

    /// Huruf pertama jadi kecil, kecuali kata dibuka singkatan (huruf kedua kapital).
    static func lc(_ s: String) -> String {
        let chars = Array(s)
        guard chars.count > 1 else { return s }
        let second = String(chars[1])
        guard second == second.lowercased() else { return s }
        return String(chars[0]).lowercased() + String(chars.dropFirst())
    }

    static func listJoin(_ a: [String]) -> String {
        guard a.count >= 2 else { return a.first ?? "" }
        return a.dropLast().joined(separator: ", ") + (a.count > 2 ? "," : "") + " dan " + a[a.count - 1]
    }

    static func platLabel(_ key: String) -> String { plats.first { $0.0 == key }?.1 ?? key }
    static func tone(_ key: String) -> Tone { tones.first { $0.key == key } ?? tones[0] }

    // MARK: - Konteks niche

    static func customContext(_ t: String) -> NicheContext {
        NicheContext(
            label: t, audience: "kamu yang tertarik dengan \(t)", activity: t, goal: "makin jago soal \(t)",
            problem: "hasilnya nggak sesuai harapan", past: "Dulu aku bingung harus mulai \(t) dari mana.",
            win: "aku makin percaya diri soal \(t)",
            tips: [
                ["Kuasai dasarnya dulu", "Sebelum mencoba trik yang rumit, pahami dulu dasar-dasar \(t). Fondasi yang kuat membuat langkah berikutnya lebih mudah.", "langsung loncat ke teknik yang rumit"],
                ["Belajar dari yang sudah berhasil", "Cari tiga orang yang sudah sukses di \(t), lalu perhatikan kebiasaan yang sama di antara mereka.", "mencoba semuanya sendiri tanpa referensi"],
                ["Latihan sedikit tapi setiap hari", "Lima belas menit setiap hari lebih efektif daripada tiga jam seminggu sekali.", "cuma belajar kalau sedang semangat"],
                ["Catat hasil dan evaluasi", "Tulis apa yang berhasil dan apa yang tidak. Dari situ kamu tahu harus memperbaiki apa.", "mengulang cara yang sama tanpa evaluasi"],
                ["Fokus ke satu hal dulu", "Pilih satu bagian yang paling penting, kuasai, baru pindah ke bagian lain.", "mencoba semua hal sekaligus"],
                ["Minta masukan dari orang lain", "Pandangan orang lain sering menunjukkan hal yang tidak kita sadari.", "takut menunjukkan hasil ke orang lain"]
            ])
    }

    static func context(_ b: Brief) -> NicheContext {
        let topic = b.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard b.niche != "lain", let n = Bank.niches.first(where: { $0.key == b.niche }) else {
            return customContext(topic.isEmpty ? "konten kreatif" : topic)
        }
        return NicheContext(label: n.label, audience: n.audience, activity: topic.isEmpty ? n.activity : topic,
                            goal: n.goal, problem: n.problem, past: n.past, win: n.win, tips: n.tips)
    }

    // MARK: - Ide

    static func offlineIdeas(_ b: Brief) -> [Idea] {
        let c = context(b)
        let n = tipsPerDuration[b.dur] ?? 3
        return formats.shuffled().prefix(5).map { f in
            let k = max(1, min(f.many ?? n, c.tips.count, n))
            let idx = Array(Array(c.tips.indices).shuffled().prefix(k))
            let x = FormatCtx(c: c, n: k, nw: numWords[min(k, numWords.count - 1)], tip2: c.tips[idx[0]][2])
            return Idea(title: cap((f.titles.randomElement() ?? f.titles[0])(x)),
                        hook: (f.hooks.randomElement() ?? f.hooks[0])(x),
                        fmt: f.key, label: f.label, tipIdx: idx, brief: b)
        }
    }

    // MARK: - Naskah

    static func offlineScript(_ idea: Idea) -> String {
        let b = idea.brief
        let d = context(b)
        let t = tone(b.tone)
        let n = tipsPerDuration[b.dur] ?? 3
        let long = b.plat == "long" || b.dur >= 180
        let det = b.dur >= 30
        let fmt = formats.contains { $0.key == idea.fmt } ? idea.fmt : "tips"
        let many = formats.first { $0.key == fmt }?.many

        var idx = idea.tipIdx.filter { d.tips.indices.contains($0) }
        if idx.isEmpty { idx = Array(Array(d.tips.indices).shuffled().prefix(max(1, min(many ?? n, n)))) }
        let tips = idx.map { d.tips[$0] }
        let br = bridges.shuffled()

        var L: [String] = []
        let hookLower = idea.hook.lowercased()
        let skipPre = ["stop", "aku", "dulu", "kalau", "ikut", "baru"].contains { hookLower.hasPrefix($0) }
        let pre = skipPre ? "" : (t.pre.randomElement() ?? "")
        L += ["## HOOK", pre + idea.hook, "(tatap kamera)", ""]

        if long {
            L += ["## PEMBUKA", "Halo, selamat datang kembali.", "Di video ini kita bahas \(lc(idea.title)).",
                  "Video ini cocok banget buat \(d.audience).", "Tonton sampai habis, karena bagian terakhir paling sering dilewatkan.", ""]
        } else if b.dur >= 60 {
            L += ["Ini buat \(d.audience).", ""]
        }

        func ordWord(_ i: Int, _ total: Int) -> String { (total >= 3 && i == total - 1) ? "terakhir" : ordinals[min(i, ordinals.count - 1)] }

        switch fmt {
        case "tips", "pemula":
            L.append("## ISI")
            for (i, tip) in tips.enumerated() {
                L.append(tips.count == 1 ? "Caranya: \(lc(tip[0]))." : "\(cap(ordWord(i, tips.count))), \(lc(tip[0])).")
                if det { L.append(tip[1]) }
                if long { L.append(br[i % br.count]) }
                L.append("")
            }
        case "salah":
            L.append("## ISI")
            for (i, tip) in tips.enumerated() {
                L.append(tips.count == 1 ? "Kesalahannya: \(tip[2])." : "Kesalahan \(ordWord(i, tips.count)): \(tip[2]).")
                L.append("Solusinya, \(lc(tip[0]))." + (det ? " " + tip[1] : ""))
                if long { L.append(br[i % br.count]) }
                L.append("")
            }
        case "cerita":
            let a = tips[0]
            L += ["## CERITA", "Aku sudah coba macam-macam cara, tapi hasilnya begitu-begitu saja.",
                  "Sampai akhirnya aku sadar, selama ini aku \(a[2]).", "(jeda sebentar)", ""]
            L += ["## PERUBAHAN", "Jadi aku ubah satu hal: \(lc(a[0]))."]
            if det { L.append(a[1]) }
            if tips.count > 1 {
                let s = tips[1]
                L.append("Setelah itu aku tambah satu kebiasaan lagi: \(lc(s[0]))." + (b.dur >= 60 ? " " + s[1] : ""))
            }
            if long { L += [br[0], br[1]] }
            L += ["", "## HASIL", "Hasilnya? Pelan-pelan, \(d.win).", "Bukan sulap. Cuma kebiasaan kecil yang dilakukan terus.", ""]
        case "satu":
            let a = tips[0]
            L += ["## ISI", "Jawabannya: \(lc(a[0])).", "(beri jeda)"]
            if det { L.append(a[1]) }
            L.append("Kenapa ini penting? Karena kebanyakan orang justru \(a[2]).")
            if tips.count > 1 && b.dur >= 60 {
                L.append("Kalau yang ini sudah jalan, baru tambahkan langkah berikutnya: \(lc(tips[1][0])).")
            }
            if long { L += [br[0], br[1]] }
            L.append("")
        case "opini":
            let a = tips[0]
            L += ["## ISI", "Aku tahu, sebagian orang pasti nggak setuju.",
                  "Tapi coba pikir. Kalau kamu \(a[2]), wajar kalau ujungnya \(d.problem).", "Yang lebih masuk akal: \(lc(a[0]))."]
            if det { L.append(a[1]) }
            let connectors = ["Ditambah lagi", "Satu lagi", "Dan jangan lupa", "Selain itu"]
            for (i, tip) in tips.dropFirst().enumerated() {
                L.append("\(connectors[i % connectors.count]), \(lc(tip[0])).")
                if b.dur >= 60 { L.append(tip[1]) }
                if long { L.append(br[i % br.count]) }
            }
            L.append("")
        case "tantangan":
            L += ["## ATURAN MAIN", "Aturannya gampang."]
            for (i, tip) in tips.enumerated() {
                let day = 1 + Int((Double(i) * 7.0 / Double(tips.count)).rounded(.down))
                let name = ordinals[min(day, 7) - 1]
                if tips.count == 1 { L.append("Setiap hari selama seminggu: \(lc(tip[0])).") }
                else if i == 0 { L.append("Hari \(name): \(lc(tip[0])).") }
                else { L.append("Mulai hari \(name), tambahkan: \(lc(tip[0])).") }
                if det { L.append(tip[1]) }
            }
            L += ["Lakukan tujuh hari berturut-turut, dan catat progresmu setiap hari.", ""]
        default:
            break
        }

        L.append("## PENUTUP")
        if tips.count >= 2 && b.dur >= 60 && fmt != "cerita" {
            L.append("Jadi ingat \(numWords[min(tips.count, numWords.count - 1)]) hal tadi: \(listJoin(tips.map { lc($0[0]) })).")
        }
        if fmt == "salah" { L.append("Kamu paling sering melakukan yang mana? Tulis di kolom komentar.") }
        if fmt == "tantangan" { L.append("Kalau kamu ikut, tulis \"aku ikut\" di komentar.") }
        if fmt == "opini" { L.append("Kamu setuju atau nggak? Tulis pendapatmu di komentar.") }
        var cta = t.cta
        if long, let r = cta.range(of: "follow", options: .caseInsensitive) { cta.replaceSubrange(r, with: "subscribe") }
        L.append(cta)

        return L.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Perintah untuk Claude

    static func contextText(_ b: Brief) -> String {
        let d = context(b)
        let nicheName = Bank.niches.first { $0.key == b.niche }?.label ?? "umum"
        let topic = b.topic.isEmpty ? "-" : b.topic
        return "Niche: \(nicheName). Topik spesifik: \(topic). Penonton: \(d.audience). Platform: \(platLabel(b.plat)). Durasi: \(b.dur) detik. Gaya bicara: \(tone(b.tone).label)."
    }

    static func ideaPrompt(_ b: Brief) -> String {
        [
            "Kamu penulis konten video berbahasa Indonesia untuk kreator. Buat 5 ide konten yang segar dan spesifik.",
            contextText(b),
            "Setiap ide memakai sudut pandang berbeda (misalnya tips, kesalahan umum, cerita pribadi, opini, tantangan, mitos vs fakta, sebelum-sesudah).",
            "Hook adalah 1-2 kalimat pembuka yang diucapkan langsung ke kamera dan membuat orang berhenti scroll.",
            "Balas HANYA JSON tanpa teks lain, dengan bentuk:",
            "{\"ide\":[{\"judul\":\"...\",\"hook\":\"...\",\"sudut\":\"...\"}]}"
        ].joined(separator: "\n")
    }

    static func scriptPrompt(_ idea: Idea) -> String {
        let b = idea.brief
        let target = Int((Double(b.dur) * wordsPerSecond).rounded())
        let long = b.plat == "long" || b.dur >= 180
        let parts = long ? "\"## HOOK\", \"## PEMBUKA\", \"## ISI\", dan \"## PENUTUP\"" : "\"## HOOK\", \"## ISI\", dan \"## PENUTUP\""
        return [
            "Tulis naskah video yang siap dibaca di teleprompter, dalam Bahasa Indonesia lisan yang natural (boleh memakai \"aku\" dan \"kamu\").",
            contextText(b),
            "Judul: \(idea.title)",
            "Hook: \(idea.hook)",
            "Sudut: \(idea.label)",
            "Panjang target sekitar \(target) kata (durasi \(b.dur) detik).",
            "Aturan format:",
            "- Bagi menjadi bagian dengan baris judul \(parts).",
            "- Kalimat pendek, satu gagasan per baris, baris kosong di antara paragraf.",
            "- Arahan ekspresi atau gerakan ditulis dalam kurung, misalnya (tatap kamera) atau (tunjuk ke bawah), secukupnya.",
            "- Tanpa emoji, tanpa tanda bintang, tanpa markdown lain.",
            "- Informasi harus akurat dan aman; jangan menjanjikan hasil instan.",
            "- Akhiri dengan ajakan yang cocok untuk \(platLabel(b.plat)).",
            "Balas hanya naskahnya."
        ].joined(separator: "\n")
    }

    /// Mengambil objek JSON pertama dari jawaban AI, lalu membaca daftar ide.
    static func parseIdeas(_ text: String, brief: Brief) -> [Idea] {
        guard let a = text.firstIndex(of: "{"), let z = text.lastIndex(of: "}"), a < z,
              let data = String(text[a...z]).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = (obj["ide"] ?? obj["ideas"]) as? [[String: Any]] else { return [] }
        return list.prefix(5).compactMap { x -> Idea? in
            let title = (x["judul"] ?? x["title"]) as? String ?? ""
            let hook = x["hook"] as? String ?? ""
            guard !title.isEmpty, !hook.isEmpty else { return nil }
            let angle = x["sudut"] as? String ?? ""
            return Idea(title: title, hook: hook, fmt: "ai", label: angle.isEmpty ? "Ide" : angle, brief: brief, fromAI: true)
        }
    }
}
