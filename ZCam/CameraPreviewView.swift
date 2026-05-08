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
            let interfaceOrientation = previewView.window?.windowScene?.interfaceOrientation ?? .portrait
            let convertedPoint = convertedLayerPoint(
                from: layerPoint,
                in: previewView.bounds,
                interfaceOrientation: interfaceOrientation
            )
            let devicePoint = previewView.previewLayer.captureDevicePointConverted(fromLayerPoint: convertedPoint)
            let screenPoint = CGPoint(
                x: layerPoint.x / previewView.bounds.width,
                y: layerPoint.y / previewView.bounds.height
            )
            onTap?(devicePoint, screenPoint)
        }

        @objc func handleDoubleTap() {
            onTap?(CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.5))
        }

        private func convertedLayerPoint(from point: CGPoint,
                                         in bounds: CGRect,
                                         interfaceOrientation: UIInterfaceOrientation) -> CGPoint {
            guard bounds.width > 0, bounds.height > 0 else { return point }

            let normalizedX = point.x / bounds.width
            let normalizedY = point.y / bounds.height

            switch interfaceOrientation {
            case .landscapeLeft:
                return CGPoint(
                    x: normalizedY * bounds.width,
                    y: (1 - normalizedX) * bounds.height
                )
            case .landscapeRight:
                return CGPoint(
                    x: (1 - normalizedY) * bounds.width,
                    y: normalizedX * bounds.height
                )
            default:
                return point
            }
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
        // CALayerのアニメーションを無効化してフレーム更新をアニメーションなしで反映する
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        // プレビュー表示は portrait 基準で固定する
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        CATransaction.commit()
    }
}
