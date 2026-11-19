import SwiftUI
import AVFoundation

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let c = previewLayer.connection, c.isVideoOrientationSupported {
            c.videoOrientation = .portrait
        }
    }
}

/// Pratinjau kamera. Memakai resizeAspect supaya bingkai yang terlihat sama dengan yang direkam.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.backgroundColor = .black
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspect
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let c = uiView.previewLayer.connection, c.isVideoOrientationSupported {
            c.videoOrientation = .portrait
        }
    }
}
