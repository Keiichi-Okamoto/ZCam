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

    @Published var inputLevels: Float {
        didSet { UserDefaults.standard.set(inputLevels, forKey: Keys.inputLevels) }
    }
    @Published var inputEdgeIntensity: Float {
        didSet { UserDefaults.standard.set(inputEdgeIntensity, forKey: Keys.inputEdgeIntensity) }
    }
    @Published var inputThreshold: Float {
        didSet { UserDefaults.standard.set(inputThreshold, forKey: Keys.inputThreshold) }
    }

    private let posterize = CIFilter(name: "CIColorPosterize")!
    private let lineOverlay = CIFilter(name: "CILineOverlay")!
    private let multiply = CIFilter(name: "CIMultiplyBlendMode")!

    init() {
        posterize.setDefaults()
        lineOverlay.setDefaults()
        inputLevels = Self.stored(Keys.inputLevels, default: Defaults.inputLevels)
        inputEdgeIntensity = Self.stored(Keys.inputEdgeIntensity, default: Defaults.inputEdgeIntensity)
        inputThreshold = Self.stored(Keys.inputThreshold, default: Defaults.inputThreshold)
    }

    func apply(to image: CIImage) -> CIImage {
        // CIFilter はスレッドセーフでないため、パラメータをローカルコピーして使用する
        let levels = inputLevels
        let edgeIntensity = inputEdgeIntensity
        let threshold = inputThreshold

        posterize.setValue(image, forKey: kCIInputImageKey)
        posterize.setValue(levels, forKey: Keys.inputLevels)
        guard let posterized = posterize.outputImage else { return image }

        lineOverlay.setValue(image, forKey: kCIInputImageKey)
        lineOverlay.setValue(edgeIntensity, forKey: Keys.inputEdgeIntensity)
        lineOverlay.setValue(threshold, forKey: Keys.inputThreshold)
        guard let lines = lineOverlay.outputImage else { return posterized }

        multiply.setValue(posterized, forKey: kCIInputImageKey)
        multiply.setValue(lines, forKey: kCIInputBackgroundImageKey)
        return multiply.outputImage ?? posterized
    }

    private static func stored(_ key: String, default fallback: Float) -> Float {
        let ud = UserDefaults.standard
        return ud.object(forKey: key) != nil ? ud.float(forKey: key) : fallback
    }
}
