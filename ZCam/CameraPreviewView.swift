import MetalKit
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let frameStore: CameraFrameStore
    let filterPipeline: FilterPipeline
    /// viewPoint: MTKView.bounds 基準の正規化座標、devicePoint: AVCaptureDevice の pointOfInterest 座標。
    var onTap: ((_ viewPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?
    var onCenterPointChange: ((_ viewPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?
    #if targetEnvironment(simulator)
    var zoomFactor: CGFloat = 1.0
    #endif

    func makeUIView(context: Context) -> UIView {
        let view = CenterReportingMTKView()
        view.backgroundColor = .black
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.colorPixelFormat = .bgra8Unorm

        if let device = MTLCreateSystemDefaultDevice(),
           let renderer = MetalRenderer(device: device, frameStore: frameStore, filterPipeline: filterPipeline) {
            view.device = device
            view.delegate = renderer
            context.coordinator.retainedRenderer = renderer
        }

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.numberOfTapsRequired = 1
        view.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        tap.require(toFail: doubleTap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onCenterPointChange = onCenterPointChange
        DispatchQueue.main.async {
            context.coordinator.reportCenterPoint(in: uiView)
        }
        #if targetEnvironment(simulator)
        context.coordinator.retainedRenderer?.zoomFactor = zoomFactor
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onCenterPointChange: onCenterPointChange)
    }

    final class Coordinator: NSObject {
        var onTap: ((_ viewPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?
        var onCenterPointChange: ((_ viewPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?
        var retainedRenderer: MetalRenderer?
        private var lastCenterPoint: (viewPoint: CGPoint, devicePoint: CGPoint)?

        init(onTap: ((_ viewPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?,
             onCenterPointChange: ((_ viewPoint: CGPoint, _ devicePoint: CGPoint) -> Void)?) {
            self.onTap = onTap
            self.onCenterPointChange = onCenterPointChange
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let previewView = gesture.view else { return }
            let point = gesture.location(in: previewView)
            let viewPoint = normalizedPoint(from: point, in: previewView.bounds)
            onTap?(viewPoint, devicePoint(from: viewPoint))
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let previewView = gesture.view else { return }
            let center = centerPoint(in: previewView)
            onTap?(center.viewPoint, center.devicePoint)
        }

        func reportCenterPoint(in view: UIView) {
            let center = centerPoint(in: view)
            guard shouldReportCenterPoint(center) else { return }
            lastCenterPoint = center
            onCenterPointChange?(center.viewPoint, center.devicePoint)
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

        private func devicePoint(from viewPoint: CGPoint) -> CGPoint {
            // Captured frames are rendered portrait-up with videoRotationAngle = 90.
            // AVCaptureDevice pointOfInterest remains in the camera sensor's landscape coordinate space.
            CGPoint(
                x: min(max(viewPoint.y, 0), 1),
                y: min(max(1 - viewPoint.x, 0), 1)
            )
        }

        private func centerPoint(in bounds: CGRect) -> (viewPoint: CGPoint, devicePoint: CGPoint) {
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let viewPoint = normalizedPoint(from: center, in: bounds)
            return (viewPoint, devicePoint(from: viewPoint))
        }

        private func centerPoint(in view: UIView) -> (viewPoint: CGPoint, devicePoint: CGPoint) {
            guard let window = view.window else {
                return centerPoint(in: view.bounds)
            }

            let windowCenter = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            let centerInView = view.convert(windowCenter, from: window)
            let viewPoint = normalizedPoint(from: centerInView, in: view.bounds)
            return (viewPoint, devicePoint(from: viewPoint))
        }

        private func shouldReportCenterPoint(_ point: (viewPoint: CGPoint, devicePoint: CGPoint)) -> Bool {
            guard let lastCenterPoint else { return true }
            return !approximatelyEqual(point.viewPoint, lastCenterPoint.viewPoint) ||
                !approximatelyEqual(point.devicePoint, lastCenterPoint.devicePoint)
        }

        private func approximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
            abs(lhs.x - rhs.x) < 0.0001 && abs(lhs.y - rhs.y) < 0.0001
        }
    }

    final class CenterReportingMTKView: MTKView {
        var observation1: NSKeyValueObservation?
        var observation2: NSKeyValueObservation?

        convenience init() {
            self.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0), device: nil)
            observation1 = observe(\.frame, options: [.new]) { _, change in
                print("\(#function) \(change.newValue?.width ?? -1) \(change.newValue?.height ?? -1)")
            }
            observation2 = observe(\.bounds, options: [.new]) { _, change in
                print("\(#function) \(change.newValue?.width ?? -1) \(change.newValue?.height ?? -1)")
            }
        }

        override init(frame frameRect: CGRect, device: (any MTLDevice)?) {
            super.init(frame: frameRect, device: device)
        }

        required init(coder: NSCoder) {
            super.init(coder: coder)
        }
    }
}
