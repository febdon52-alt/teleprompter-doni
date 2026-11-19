import SwiftUI
import Combine
import QuartzCore

/// Menggulir naskah dengan CADisplayLink supaya mulus dan tidak membebani tampilan lain.
final class ScrollEngine: NSObject, ObservableObject {
    @Published var playing = false

    /// Posisi gulir dikirim lewat subject agar hanya tampilan teks yang digambar ulang tiap frame.
    let offsetSubject = CurrentValueSubject<CGFloat, Never>(0)
    var offset: CGFloat = 0 { didSet { offsetSubject.send(offset) } }
    var maxOffset: CGFloat = 0
    var speed: Double = 5          // 1...15
    var fontSize: CGFloat = 40
    var played: Double = 0         // detik yang sudah berjalan
    var onFinish: (() -> Void)?

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0

    var pixelsPerSecond: CGFloat { CGFloat(speed) * 0.1 * fontSize * 1.36 }

    func play() {
        guard !playing else { return }
        if offset >= maxOffset { offset = 0; played = 0 }
        playing = true
        last = 0
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func pause() {
        link?.invalidate()
        link = nil
        if playing { playing = false }
    }

    func toggle() { playing ? pause() : play() }

    func rewind() {
        offset = 0
        played = 0
    }

    func scroll(to value: CGFloat) {
        offset = max(0, min(maxOffset, value))
    }

    @objc private func tick(_ l: CADisplayLink) {
        if last == 0 { last = l.timestamp; return }
        let dt = min(0.1, l.timestamp - last)
        last = l.timestamp
        offset = min(maxOffset, offset + pixelsPerSecond * CGFloat(dt))
        played += dt
        if offset >= maxOffset {
            pause()
            onFinish?()
        }
    }

    deinit { link?.invalidate() }
}

// MARK: - Naskah → baris tampilan

enum PromptLine: Equatable {
    case section(String)
    case direction(String)
    case text(String)
    case gap
}

enum PromptParser {
    static func parse(_ source: String) -> [PromptLine] {
        var out: [PromptLine] = []
        for raw in source.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { out.append(.gap); continue }
            if line.hasPrefix("#") {
                let title = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                out.append(.section(title))
                continue
            }
            if line.hasPrefix("(") && line.hasSuffix(")") && !line.dropFirst().dropLast().contains(")") {
                out.append(.direction(line))
                continue
            }
            out.append(.text(line))
        }
        return out
    }
}
