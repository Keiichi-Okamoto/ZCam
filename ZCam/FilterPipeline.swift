import Combine
import CoreImage

final class FilterPipeline: ObservableObject {
    private enum Keys {
        static let inputLevels = "inputLevels"
        static let inputEdgeIntensity = "inputEdgeIntensity"
        static let inputThreshold = "inputThreshold"
    }

    private enum Defaults {
        static let inputLevels: Float = 6
        static let inputEdgeIntensity: Float = 1
        static let inputThreshold: Float = 0.1
    }

    // レンダリングスレッドから読む安全なスナップショット
    struct Snapshot {
        var inputLevels: Float
        var inputEdgeIntensity: Float
        var inputThreshold: Float
    }

    private let lock = NSLock()
    private var _snapshot: Snapshot

    var snapshot: Snapshot {
        lock.withLock { _snapshot }
    }

    @Published var inputLevels: Float {
        didSet {
            lock.withLock { _snapshot.inputLevels = inputLevels }
            UserDefaults.standard.set(inputLevels, forKey: Keys.inputLevels)
        }
    }
    @Published var inputEdgeIntensity: Float {
        didSet {
            lock.withLock { _snapshot.inputEdgeIntensity = inputEdgeIntensity }
            UserDefaults.standard.set(inputEdgeIntensity, forKey: Keys.inputEdgeIntensity)
        }
    }
    @Published var inputThreshold: Float {
        didSet {
            lock.withLock { _snapshot.inputThreshold = inputThreshold }
            UserDefaults.standard.set(inputThreshold, forKey: Keys.inputThreshold)
        }
    }

    private let posterize = CIFilter(name: "CIColorPosterize")!
    private let lineOverlay = CIFilter(name: "CILineOverlay")!
    private let multiply = CIFilter(name: "CIMultiplyBlendMode")!

    init() {
        posterize.setDefaults()
        lineOverlay.setDefaults()
        multiply.setDefaults()
        let levels = Self.stored(Keys.inputLevels, default: Defaults.inputLevels)
        let edgeIntensity = Self.stored(Keys.inputEdgeIntensity, default: Defaults.inputEdgeIntensity)
        let threshold = Self.stored(Keys.inputThreshold, default: Defaults.inputThreshold)
        inputLevels = levels
        inputEdgeIntensity = edgeIntensity
        inputThreshold = threshold
        _snapshot = Snapshot(inputLevels: levels, inputEdgeIntensity: edgeIntensity, inputThreshold: threshold)
    }

    func apply(to image: CIImage) -> CIImage {
        // メインスレッドの @Published 書き込みと競合しないよう snapshot 経由で読む
        let snap = snapshot

        posterize.setValue(image, forKey: kCIInputImageKey)
        posterize.setValue(snap.inputLevels, forKey: Keys.inputLevels)
        guard let posterized = posterize.outputImage else { return image }

        lineOverlay.setValue(image, forKey: kCIInputImageKey)
        lineOverlay.setValue(snap.inputEdgeIntensity, forKey: Keys.inputEdgeIntensity)
        lineOverlay.setValue(snap.inputThreshold, forKey: Keys.inputThreshold)
        guard let lines = lineOverlay.outputImage else { return posterized }

        multiply.setValue(posterized, forKey: kCIInputImageKey)
        multiply.setValue(lines, forKey: kCIInputBackgroundImageKey)
        return multiply.outputImage ?? posterized
    }

    private static func stored(_ key: String, default fallback: Float) -> Float {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) != nil ? defaults.float(forKey: key) : fallback
    }
}
