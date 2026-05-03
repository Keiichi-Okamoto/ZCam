import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// devicePoint: AVFoundation座標（フォーカス設定用）、screenPoint: 正規化スクリーン座標（インジケーター表示用）
    var onTap: ((_ devicePoint: CGPoint, _ screenPoint: CGPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.numberOfTapsRequired = 1
        view.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        tap.require(toFail: doubleTap)

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        var onTap: ((_ devicePoint: CGPoint, _ screenPoint: CGPoint) -> Void)?

        init(onTap: ((_ devicePoint: CGPoint, _ screenPoint: CGPoint) -> Void)?) {
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let previewView = gesture.view as? PreviewView else { return }
            let layerPoint = gesture.location(in: previewView)
            let devicePoint = previewView.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            let screenPoint = CGPoint(
                x: layerPoint.x / previewView.bounds.width,
                y: layerPoint.y / previewView.bounds.height
            )
            onTap?(devicePoint, screenPoint)
        }

        @objc func handleDoubleTap() {
            onTap?(CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.5))
        }
    }
}

final class PreviewView: UIView {
    override static var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClassをAVCaptureVideoPreviewLayerに固定しているため常に成功する
        layer as! AVCaptureVideoPreviewLayer // swiftlint:disable:this force_cast
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            let angle: CGFloat
            switch window?.windowScene?.interfaceOrientation {
            case .landscapeLeft:            angle = 180
            case .landscapeRight:           angle = 0
            case .portraitUpsideDown:       angle = 270
            default:                        angle = 90
            }
            connection.videoRotationAngle = angle
        }
    }
}
