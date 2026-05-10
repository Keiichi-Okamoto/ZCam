import CoreImage
import Foundation

final class CameraFrameStore: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var latestImage: CIImage?

    nonisolated func update(_ image: CIImage) {
        lock.lock()
        latestImage = image
        lock.unlock()
    }

    nonisolated func image() -> CIImage? {
        lock.lock()
        defer { lock.unlock() }
        return latestImage
    }
}
