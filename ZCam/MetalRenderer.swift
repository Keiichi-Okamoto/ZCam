import CoreImage
import Metal
import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let frameStore: CameraFrameStore
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let filterPipeline: FilterPipeline
    #if targetEnvironment(simulator)
    var zoomFactor: CGFloat = 1.0
    #endif

    init?(device: MTLDevice, frameStore: CameraFrameStore, filterPipeline: FilterPipeline) {
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.frameStore = frameStore
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlDevice: device)
        self.filterPipeline = filterPipeline
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let image = frameStore.image(),
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let drawableSize = view.drawableSize
        let bounds = CGRect(origin: .zero, size: drawableSize)
        let filled = aspectFill(image: image, in: bounds)
        #if targetEnvironment(simulator)
        let zoomed = applyZoom(image: filled, in: bounds)
        let renderImage = filterPipeline.apply(to: zoomed)
        #else
        let renderImage = filterPipeline.apply(to: filled)
        #endif

        ciContext.render(
            renderImage,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: bounds,
            colorSpace: colorSpace
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    #if targetEnvironment(simulator)
    private func applyZoom(image: CIImage, in bounds: CGRect) -> CIImage {
        guard zoomFactor != 1.0 else { return image }
        let tx = bounds.midX * (1 - zoomFactor)
        let ty = bounds.midY * (1 - zoomFactor)
        return image
            .transformed(by: CGAffineTransform(scaleX: zoomFactor, y: zoomFactor)
                .translatedBy(x: tx / zoomFactor, y: ty / zoomFactor))
            .cropped(to: bounds)
    }
    #endif

    private func aspectFill(image: CIImage, in bounds: CGRect) -> CIImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0, bounds.width > 0, bounds.height > 0 else {
            return image
        }

        let scale = max(bounds.width / extent.width, bounds.height / extent.height)
        let scaledWidth = extent.width * scale
        let scaledHeight = extent.height * scale
        let offsetX = (bounds.width - scaledWidth) / 2
        let offsetY = (bounds.height - scaledHeight) / 2

        return image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            .cropped(to: bounds)
    }
}
