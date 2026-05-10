import CoreImage
import Metal
import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let frameStore: CameraFrameStore
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    let filterPipeline = FilterPipeline()

    init?(device: MTLDevice, frameStore: CameraFrameStore) {
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.frameStore = frameStore
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlDevice: device)
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
        let renderImage = filterPipeline.apply(to: filled)

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
