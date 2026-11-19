import AVFoundation
import Photos
import UIKit

/// Rasio video yang bisa direkam langsung oleh sensor kamera depan (tanpa dipotong ulang).
enum VideoRatio: String, CaseIterable, Identifiable, Codable {
    case r916 = "9:16"   // layar penuh vertikal
    case r34 = "3:4"     // bidang pandang lebih lebar

    var id: String { rawValue }
}

struct RecordingResult: Identifiable {
    let id = UUID()
    let url: URL
    var saved: Bool
    var message: String
    var seconds: Double
    var bytes: Int64
}

/// Merekam dari kamera depan memakai encoder bawaan iPhone (ringan, jernih) lalu menyimpannya ke app Foto.
final class CameraController: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    let session = AVCaptureSession()

    @Published var isRecording = false
    @Published var zoom: CGFloat = 1
    @Published var maxZoom: CGFloat = 1
    @Published var info = ""
    @Published var error: String?
    @Published var result: RecordingResult?
    @Published var recStart: Date?
    @Published var running = false

    private let queue = DispatchQueue(label: "bacakamera.session")
    private var device: AVCaptureDevice?
    private let movie = AVCaptureMovieFileOutput()
    private var configured = false
    private var ratio: VideoRatio = .r916
    private var mirrorRecording = false
    private var stopAfterRecording = false

    // MARK: - Izin

    func requestPermissions(_ done: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { video in
            AVCaptureDevice.requestAccess(for: .audio) { audio in
                DispatchQueue.main.async { done(video && audio) }
            }
        }
    }

    // MARK: - Sesi

    func start(ratio: VideoRatio, mirror: Bool) {
        queue.async {
            self.ratio = ratio
            self.mirrorRecording = mirror
            if !self.configured { self.configureSession() }
            guard self.configured else { return }
            self.applyFormat()
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.running = true }
        }
    }

    func stop() {
        queue.async {
            if self.movie.isRecording {
                self.stopAfterRecording = true
                self.movie.stopRecording()
            } else if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async { self.running = false }
        }
    }

    /// Dipanggil saat rasio atau pencerminan berubah dan kamera sedang menyala.
    func reconfigure(ratio: VideoRatio, mirror: Bool) {
        queue.async {
            guard self.configured, !self.movie.isRecording else { return }
            self.ratio = ratio
            self.mirrorRecording = mirror
            self.applyFormat()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .inputPriority

        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoIn = try? AVCaptureDeviceInput(device: dev),
              session.canAddInput(videoIn) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.error = "Kamera depan tidak tersedia di perangkat ini." }
            return
        }
        session.addInput(videoIn)
        device = dev

        if let mic = AVCaptureDevice.default(for: .audio),
           let audioIn = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(audioIn) {
            session.addInput(audioIn)
        }
        if session.canAddOutput(movie) { session.addOutput(movie) }
        session.commitConfiguration()
        configured = true
    }

    /// Memilih format kamera dengan rasio yang diminta, resolusi tertinggi sampai 1080p, 30 fps.
    private func applyFormat() {
        guard let dev = device else { return }
        let want43 = ratio == .r34
        let pixelCap = want43 ? 1920 * 1440 : 1920 * 1080

        var best: AVCaptureDevice.Format?
        var bestPixels = 0
        for f in dev.formats {
            let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
            let w = Int(d.width), h = Int(d.height)
            let isMatch = want43 ? (w * 3 == h * 4) : (w * 9 == h * 16)
            guard isMatch, w * h <= pixelCap else { continue }
            guard f.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }) else { continue }
            if w * h > bestPixels { best = f; bestPixels = w * h }
        }

        var note = ""
        do {
            try dev.lockForConfiguration()
            if let b = best {
                dev.activeFormat = b
            } else {
                note = " (rasio ini tidak tersedia, memakai bawaan)"
            }
            dev.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            dev.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            let hi = max(1, min(dev.activeFormat.videoMaxZoomFactor, 6))
            dev.videoZoomFactor = max(1, min(dev.videoZoomFactor, hi))
            dev.unlockForConfiguration()
        } catch {
            note = " (format tidak bisa diatur)"
        }

        let dims = CMVideoFormatDescriptionGetDimensions(dev.activeFormat.formatDescription)
        let shortSide = Int(min(dims.width, dims.height)), longSide = Int(max(dims.width, dims.height))
        let maxZ = max(1, min(dev.activeFormat.videoMaxZoomFactor, 6))
        let z = dev.videoZoomFactor
        DispatchQueue.main.async {
            self.info = "\(shortSide)×\(longSide)\(note)"
            self.maxZoom = maxZ
            self.zoom = z
        }
    }

    // MARK: - Zoom

    func setZoom(_ value: CGFloat) {
        queue.async {
            guard let dev = self.device else { return }
            let hi = max(1, min(dev.activeFormat.videoMaxZoomFactor, 6))
            let v = max(1, min(hi, value))
            do {
                try dev.lockForConfiguration()
                dev.videoZoomFactor = v
                dev.unlockForConfiguration()
            } catch { return }
            DispatchQueue.main.async { self.zoom = v }
        }
    }

    // MARK: - Rekam

    func startRecording() {
        queue.async {
            guard self.session.isRunning, !self.movie.isRecording else { return }
            if let c = self.movie.connection(with: .video) {
                if c.isVideoOrientationSupported { c.videoOrientation = .portrait }
                c.automaticallyAdjustsVideoMirroring = false
                if c.isVideoMirroringSupported { c.isVideoMirrored = self.mirrorRecording }
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("rekaman-\(Int(Date().timeIntervalSince1970)).mov")
            try? FileManager.default.removeItem(at: url)
            self.movie.startRecording(to: url, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
                self.recStart = Date()
            }
        }
    }

    func stopRecording() {
        queue.async {
            if self.movie.isRecording { self.movie.stopRecording() }
        }
    }

    // MARK: - Hasil

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        // iOS kadang melaporkan galat padahal berkas selesai ditulis (misalnya ruang penuh): cek penanda sukses.
        let nsError = error as NSError?
        let finished = (nsError?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) ?? (error == nil)
        let size = ((try? FileManager.default.attributesOfItem(atPath: outputFileURL.path))?[.size] as? NSNumber)?.int64Value ?? 0
        let seconds = CMTimeGetSeconds(output.recordedDuration)

        DispatchQueue.main.async {
            self.isRecording = false
            self.recStart = nil
        }
        if stopAfterRecording {
            stopAfterRecording = false
            queue.async { if self.session.isRunning { self.session.stopRunning() } }
        }

        guard size > 0, finished || size > 1024 else {
            DispatchQueue.main.async {
                self.error = "Rekaman gagal disimpan" + (nsError.map { " (\($0.localizedDescription))" } ?? "") + "."
            }
            return
        }
        saveToPhotos(outputFileURL, seconds: seconds.isFinite ? seconds : 0, bytes: size,
                     warning: finished ? nil : "Rekaman berhenti di tengah jalan, bagian yang sudah terekam diselamatkan.")
    }

    private func saveToPhotos(_ url: URL, seconds: Double, bytes: Int64, warning: String?) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                self.finish(url, saved: false, seconds: seconds, bytes: bytes,
                            message: "Izin Foto ditolak. Video disimpan di aplikasi (Files › Baca Kamera). Izinkan Foto di Pengaturan iPhone, atau bagikan videonya di bawah.")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }, completionHandler: { ok, err in
                if ok {
                    self.finish(url, saved: true, seconds: seconds, bytes: bytes,
                                message: warning ?? "Tersimpan di app Foto.")
                } else {
                    self.finish(url, saved: false, seconds: seconds, bytes: bytes,
                                message: "Gagal menyimpan ke Foto" + (err.map { " (\($0.localizedDescription))" } ?? "") + ". Video aman di aplikasi (Files › Baca Kamera); bagikan videonya di bawah.")
                }
            })
        }
    }

    private func finish(_ url: URL, saved: Bool, seconds: Double, bytes: Int64, message: String) {
        var shown = url
        if !saved { shown = keepLocal(url) }
        DispatchQueue.main.async {
            self.result = RecordingResult(url: shown, saved: saved, message: message, seconds: seconds, bytes: bytes)
        }
    }

    /// Memindahkan video yang gagal masuk ke Foto ke folder aplikasi supaya tidak hilang.
    private func keepLocal(_ url: URL) -> URL {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return url }
        let dir = docs.appendingPathComponent("Rekaman", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(url.lastPathComponent)
        try? fm.removeItem(at: dest)
        do { try fm.moveItem(at: url, to: dest); return dest } catch { return url }
    }
}
