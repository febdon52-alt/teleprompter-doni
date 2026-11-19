import SwiftUI

enum Theme {
    static let ink = Color(red: 0.059, green: 0.071, blue: 0.090)
    static let panel = Color(red: 0.090, green: 0.106, blue: 0.133)
    static let raise = Color(red: 0.122, green: 0.141, blue: 0.176)
    static let line = Color(red: 0.165, green: 0.188, blue: 0.231)
    static let muted = Color(red: 0.584, green: 0.616, blue: 0.675)
    static let cue = Color(red: 0.957, green: 0.714, blue: 0.247)
    static let cueInk = Color(red: 0.122, green: 0.086, blue: 0.016)
    static let rec = Color(red: 1.0, green: 0.271, blue: 0.227)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(Theme.cueInk)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.cue.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var danger = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(danger ? Theme.rec : .white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.raise.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

func fmtTime(_ s: Double) -> String {
    let t = max(0, Int(s.rounded()))
    return String(format: "%02d:%02d", t / 60, t % 60)
}

/// Pilihan berbentuk kapsul yang membungkus ke baris berikutnya.
struct ChipGrid: View {
    let items: [(String, String)]
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.0) { item in
                Button {
                    selection = item.0
                } label: {
                    Text(item.1)
                        .font(.system(size: 15, weight: selection == item.0 ? .bold : .regular))
                        .foregroundColor(selection == item.0 ? Theme.cueInk : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(selection == item.0 ? Theme.cue : Theme.panel)
                        .overlay(Capsule().stroke(selection == item.0 ? Theme.cue : Theme.line))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
