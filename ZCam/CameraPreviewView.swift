import MetalKit
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let frameStore: CameraFrameStore
    /// devicePoint: AVFoundation座標（フォーカス設定用）、screenPoint: 正規化スクリーン座標（インジケーター表示用）
    var onTap: ((_ devicePoint: CGPoint, _ screenPoint: CGPoint) -> Void)?
    #if targetEnvironment(simulator)
    var zoomFactor: CGFloat = 1.0
    #endif

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.backgroundColor = .black
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.colorPixelFormat = .bgra8Unorm

        if let device = MTLCreateSystemDefaultDevice(),
           let renderer = MetalRenderer(device: device, frameStore: frameStore) {
            view.device = device
            view.delegate = renderer
            context.coordinator.retainedRenderer = renderer
        }

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.numberOfTapsRequired = 1
        view.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        tap.require(toFail: doubleTap)

        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.onTap = onTap
        #if targetEnvironment(simulator)
        context.coordinator.retainedRenderer?.zoomFactor = zoomFactor
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        var onTap: ((_ devicePoint: CGPoint, _ screenPoint: CGPoint) -> Void)?
        var retainedRenderer: MetalRenderer?

        init(onTap: ((_ devicePoint: CGPoint, _ screenPoint: CGPoint) -> Void)?) {
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let previewView = gesture.view else { return }
            let point = gesture.location(in: previewView)
            let screenPoint = normalizedPoint(from: point, in: previewView.bounds)
            // TODO: 700 で MTKView の crop / rotation を含めた screenPoint -> devicePoint 変換を実装する。
            let provisionalDevicePoint = screenPoint
            onTap?(provisionalDevicePoint, screenPoint)
        }

        @objc func handleDoubleTap() {
            onTap?(CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.5))
        }

        private func normalizedPoint(from point: CGPoint, in bounds: CGRect) -> CGPoint {
            guard bounds.width > 0, bounds.height > 0 else {
                return CGPoint(x: 0.5, y: 0.5)
            }

            return CGPoint(
                x: min(max(point.x / bounds.width, 0), 1),
                y: min(max(point.y / bounds.height, 0), 1)
            )
        }
    }
}
