import SwiftUI
import Combine
import AVKit

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Isi naskah. Digambar sekali; yang bergerak hanya posisinya.
struct PromptContent: View, Equatable {
    let lines: [PromptLine]
    let fontSize: CGFloat
    let center: Bool

    var body: some View {
        VStack(alignment: center ? .center : .leading, spacing: fontSize * 0.14) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                row(line)
            }
            Text("— SELESAI —")
                .font(.system(size: fontSize * 0.4, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, fontSize * 1.2)
                .padding(.bottom, fontSize * 6)
        }
        .multilineTextAlignment(center ? .center : .leading)
    }

    @ViewBuilder
    private func row(_ line: PromptLine) -> some View {
        switch line {
        case .section(let title):
            Text(title.uppercased())
                .font(.system(size: fontSize * 0.36, weight: .medium, design: .monospaced))
                .tracking(fontSize * 0.05)
                .foregroundColor(Theme.cue)
                .frame(maxWidth: .infinity, alignment: center ? .center : .leading)
                .padding(.top, fontSize * 0.7)
        case .direction(let s):
            Text(s)
                .font(.system(size: fontSize * 0.62).italic())
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity, alignment: center ? .center : .leading)
        case .text(let s):
            inline(s)
                .lineSpacing(fontSize * 0.2)
                .frame(maxWidth: .infinity, alignment: center ? .center : .leading)
        case .gap:
            Color.clear.frame(height: fontSize * 0.4)
        }
    }

    /// Teks dengan arahan dalam kurung diberi warna abu-abu miring.
    private func inline(_ s: String) -> Text {
        let body = Font.system(size: fontSize, weight: .bold)
        let dir = Font.system(size: fontSize * 0.62).italic()
        var result = Text("")
        var buffer = ""
        var inDirection = false
        for ch in s {
            if ch == "(" && !inDirection {
                if !buffer.isEmpty { result = result + Text(buffer).font(body).foregroundColor(.white) }
                buffer = "("
                inDirection = true
            } else if ch == ")" && inDirection {
                buffer += ")"
                result = result + Text(buffer).font(dir).foregroundColor(Theme.muted)
                buffer = ""
                inDirection = false
            } else {
                buffer.append(ch)
            }
        }
        if !buffer.isEmpty {
            result = result + (inDirection ? Text(buffer).font(dir).foregroundColor(Theme.muted)
                                           : Text(buffer).font(body).foregroundColor(.white))
        }
        return result
    }
}

private struct TextStage: View {
    let lines: [PromptLine]
    let fontSize: CGFloat
    let center: Bool
    let lineY: CGFloat
    let engine: ScrollEngine
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            PromptContent(lines: lines, fontSize: fontSize, center: center)
                .equatable()
                .padding(.horizontal, 24)
                .frame(width: geo.size.width, alignment: center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { g in
                    Color.clear.preference(key: HeightKey.self, value: g.size.height)
                })
                .offset(y: lineY - fontSize * 0.68 - offset)
        }
        .clipped()
        .onReceive(engine.offsetSubject) { v in offset = v }
        .onPreferenceChange(HeightKey.self) { h in engine.maxOffset = max(0, h - fontSize * 2) }
    }
}

private struct ProgressBarView: View {
    let engine: ScrollEngine
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            Rectangle().fill(Theme.cue).frame(width: g.size.width * progress, height: 3)
        }
        .frame(height: 3)
        .onReceive(engine.offsetSubject) { v in
            let n = engine.maxOffset > 0 ? min(1, v / engine.maxOffset) : 0
            if abs(n - progress) > 0.002 { progress = n }
        }
    }
}

private struct TimeLabel: View {
    let engine: ScrollEngine
    @State private var text = "00:00 / sisa 00:00"

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .monospacedDigit()
            .foregroundColor(.white)
            .onAppear { refresh() }
            .onReceive(engine.offsetSubject.throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)) { _ in refresh() }
    }

    private func refresh() {
        let rest = engine.pixelsPerSecond > 0 ? Double((engine.maxOffset - engine.offset) / engine.pixelsPerSecond) : 0
        let s = "\(fmtTime(engine.played)) / sisa \(fmtTime(rest))"
        if s != text { text = s }
    }
}

private struct ReadLine: View {
    var body: some View {
        HStack {
            Triangle().fill(Theme.cue).frame(width: 12, height: 18)
            Spacer()
            Triangle().fill(Theme.cue).frame(width: 12, height: 18).scaleEffect(x: -1, y: 1)
        }
        .allowsHitTesting(false)
    }

    private struct Triangle: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
            return p
        }
    }
}

// MARK: - Layar teleprompter

struct TeleprompterView: View {
    let text: String

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = ScrollEngine()
    @StateObject private var cam = CameraController()

    @State private var lines: [PromptLine] = []
    @State private var cameraOn = true
    @State private var chrome = true
    @State private var count: Int?
    @State private var countTask: Task<Void, Never>?
    @State private var hideTask: Task<Void, Never>?
    @State private var dragStart: CGFloat?
    @State private var dragged = false
    @State private var pinchBase: CGFloat?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if cameraOn {
                CameraPreview(session: cam.session).ignoresSafeArea()
                Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(false)
            }

            GeometryReader { geo in
                let lineY = geo.size.height * 0.30
                ZStack(alignment: .top) {
                    TextStage(lines: lines, fontSize: CGFloat(settings.fontSize), center: settings.centerText,
                              lineY: lineY, engine: engine)
                        .scaleEffect(x: settings.mirrorText ? -1 : 1, y: 1)
                    LinearGradient(colors: [.black.opacity(cameraOn ? 0.7 : 1), .black.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: max(0, lineY - CGFloat(settings.fontSize) * 0.9))
                        .allowsHitTesting(false)
                    ReadLine().offset(y: lineY - 9)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .contentShape(Rectangle())
                .gesture(stageDrag)
                .simultaneousGesture(pinch)
            }

            VStack(spacing: 0) {
                ProgressBarView(engine: engine)
                if chrome { topBar.transition(.opacity) }
                Spacer(minLength: 0)
                if chrome { bottomPanel.transition(.opacity) }
            }

            if let n = count {
                Text("\(n)")
                    .font(.system(size: 160, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.cue)
                    .shadow(radius: 8)
                    .allowsHitTesting(false)
            }
        }
        .statusBarHidden(true)
        .onAppear(perform: appear)
        .onDisappear(perform: disappear)
        .onChange(of: settings.speed) { v in engine.speed = v }
        .onChange(of: settings.fontSize) { v in
            let r = engine.maxOffset > 0 ? engine.offset / engine.maxOffset : 0
            engine.fontSize = CGFloat(v)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { engine.scroll(to: r * engine.maxOffset) }
        }
        .onChange(of: settings.ratio) { _ in cam.reconfigure(ratio: settings.ratio, mirror: settings.mirrorRecording) }
        .onChange(of: engine.playing) { playing in
            if playing { scheduleHide() } else { withAnimation { chrome = true } }
        }
        .alert("Perhatian", isPresented: Binding(get: { cam.error != nil }, set: { if !$0 { cam.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cam.error ?? "")
        }
        .sheet(item: $cam.result) { r in ResultSheet(result: r) }
    }

    // MARK: Gestur

    private var stageDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if dragStart == nil { dragStart = engine.offset; dragged = false }
                if abs(v.translation.height) > 8 { dragged = true }
                if dragged && pinchBase == nil { engine.scroll(to: (dragStart ?? 0) - v.translation.height) }
            }
            .onEnded { _ in
                if !dragged && pinchBase == nil { tapped() }
                dragStart = nil
                dragged = false
            }
    }

    private var pinch: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard cameraOn else { return }
                if pinchBase == nil { pinchBase = cam.zoom }
                cam.setZoom((pinchBase ?? 1) * scale)
            }
            .onEnded { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { pinchBase = nil }
            }
    }

    private func tapped() {
        if !chrome {
            withAnimation { chrome = true }
            if engine.playing { scheduleHide() }
        } else {
            togglePlay()
        }
    }

    // MARK: Aksi

    private func appear() {
        lines = PromptParser.parse(text)
        engine.speed = settings.speed
        engine.fontSize = CGFloat(settings.fontSize)
        engine.onFinish = { withAnimation { chrome = true } }
        UIApplication.shared.isIdleTimerDisabled = true
        if cameraOn { startCamera(then: nil) }
    }

    private func disappear() {
        UIApplication.shared.isIdleTimerDisabled = false
        countTask?.cancel()
        hideTask?.cancel()
        engine.pause()
        if cam.isRecording { cam.stopRecording() }
        cam.stop()
    }

    private func startCamera(then ok: (() -> Void)?) {
        cameraOn = true
        cam.requestPermissions { granted in
            guard granted else {
                cameraOn = false
                cam.error = "Izin kamera atau mikrofon belum diberikan. Buka Pengaturan iPhone › Baca Kamera, lalu aktifkan Kamera dan Mikrofon."
                return
            }
            cam.start(ratio: settings.ratio, mirror: settings.mirrorRecording)
            guard let ok = ok else { return }
            Task { @MainActor in
                for _ in 0..<40 {
                    if cam.session.isRunning { break }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                ok()
            }
        }
    }

    private func toggleCamera() {
        if cam.isRecording { return }
        if cameraOn { cameraOn = false; cam.stop() } else { startCamera(then: nil) }
    }

    private func togglePlay() {
        if count != nil { cancelCountdown(); return }
        if engine.playing { engine.pause() } else { startCountdown { engine.play() } }
    }

    private func toggleRecord() {
        if cam.isRecording {
            engine.pause()
            cam.stopRecording()
            return
        }
        if count != nil { cancelCountdown(); return }
        startCamera {
            engine.pause()
            engine.rewind()
            startCountdown {
                cam.startRecording()
                engine.play()
            }
        }
    }

    private func startCountdown(_ after: @escaping () -> Void) {
        let n = settings.countdown
        if n <= 0 { after(); return }
        withAnimation { chrome = false }
        countTask?.cancel()
        countTask = Task { @MainActor in
            var k = n
            while k > 0 {
                count = k
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { count = nil; return }
                k -= 1
            }
            count = nil
            after()
        }
    }

    private func cancelCountdown() {
        countTask?.cancel()
        count = nil
        withAnimation { chrome = true }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled && engine.playing { withAnimation { chrome = false } }
        }
    }

    // MARK: Panel

    private var topBar: some View {
        HStack {
            roundButton("xmark", label: "Tutup") { dismiss() }
            Spacer()
            HStack(spacing: 10) {
                if cam.isRecording, let start = cam.recStart {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.rec).frame(width: 8, height: 8)
                        TimelineView(.periodic(from: start, by: 0.5)) { ctx in
                            Text("REC \(fmtTime(ctx.date.timeIntervalSince(start)))")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(Theme.rec)
                        }
                    }
                }
                TimeLabel(engine: engine)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            Spacer()
            roundButton("arrow.counterclockwise", label: "Kembali ke awal") { engine.rewind() }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private func roundButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if cameraOn {
                Picker("Rasio", selection: $settings.ratio) {
                    ForEach(VideoRatio.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(cam.isRecording)

                if cam.maxZoom > 1.05 {
                    HStack(spacing: 10) {
                        Text("ZOOM").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(Theme.muted)
                        smallButton("minus") { cam.setZoom(cam.zoom - 0.2) }
                        Slider(value: Binding(get: { Double(cam.zoom) }, set: { cam.setZoom(CGFloat($0)) }),
                               in: 1...Double(cam.maxZoom))
                            .tint(Theme.cue)
                        smallButton("plus") { cam.setZoom(cam.zoom + 0.2) }
                        Text(String(format: "%.1f×", Double(cam.zoom)))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.muted)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                if !cam.info.isEmpty {
                    Text("Video \(cam.info) · \(settings.ratio.rawValue)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack {
                stepper(value: "\(Int(settings.speed))", caption: "KECEPATAN",
                        minus: { settings.speed = max(1, settings.speed - 0.5) },
                        plus: { settings.speed = min(15, settings.speed + 0.5) })
                Spacer(minLength: 4)
                Button(action: togglePlay) {
                    Image(systemName: engine.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.cueInk)
                        .frame(width: 68, height: 68)
                        .background(Theme.cue)
                        .clipShape(Circle())
                }
                .accessibilityLabel(engine.playing ? "Jeda" : "Putar")
                Spacer(minLength: 4)
                stepper(value: "\(Int(settings.fontSize))", caption: "HURUF",
                        minus: { settings.fontSize = max(24, settings.fontSize - 4) },
                        plus: { settings.fontSize = min(80, settings.fontSize + 4) })
            }

            HStack(spacing: 8) {
                toggle("Cermin", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", on: settings.mirrorText) { settings.mirrorText.toggle() }
                toggle("Tengah", icon: "text.aligncenter", on: settings.centerText) { settings.centerText.toggle() }
                toggle("Kamera", icon: "video", on: cameraOn) { toggleCamera() }
                toggle(cam.isRecording ? "Berhenti" : "Rekam", icon: cam.isRecording ? "stop.fill" : "circle.fill",
                       on: cam.isRecording, danger: true) { toggleRecord() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(red: 0.059, green: 0.071, blue: 0.09).opacity(0.96))
    }

    private func smallButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Theme.raise)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func stepper(value: String, caption: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            smallButton("minus", action: minus)
            VStack(spacing: 2) {
                Text(value).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundColor(.white)
                Text(caption).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundColor(Theme.muted)
            }
            .frame(minWidth: 52)
            smallButton("plus", action: plus)
        }
    }

    private func toggle(_ title: String, icon: String, on: Bool, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 17))
                Text(title).font(.system(size: 12))
            }
            .foregroundColor(on ? (danger ? Theme.rec : Theme.cue) : .white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.raise)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? (danger ? Theme.rec : Theme.cue) : Theme.line))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Hasil rekaman

struct ResultSheet: View {
    let result: RecordingResult
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 14) {
            Text("Hasil rekaman").font(.title2.bold())
            VideoPlayer(player: player)
                .frame(maxHeight: 380)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Label(result.message, systemImage: result.saved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(result.saved ? .green : Theme.cue)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(fmtTime(result.seconds)) · \(ByteCountFormatter.string(fromByteCount: result.bytes, countStyle: .file))")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !result.saved {
                ShareLink(item: result.url) {
                    Label("Bagikan atau simpan ke Files", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            Button("Tutup") { dismiss() }.buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
        .background(Theme.ink.ignoresSafeArea())
        .presentationDetents([.large])
        .onAppear { player = AVPlayer(url: result.url) }
        .onDisappear {
            player?.pause()
            if result.saved { try? FileManager.default.removeItem(at: result.url) }
        }
    }
}
