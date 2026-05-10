import CoreImage

final class FilterPipeline {
    var inputLevels: Float
    var inputEdgeIntensity: Float
    var inputThreshold: Float

    private let posterize = CIFilter(name: "CIColorPosterize")!
    private let lineOverlay = CIFilter(name: "CILineOverlay")!
    private let multiply = CIFilter(name: "CIMultiplyBlendMode")!

    init() {
        posterize.setDefaults()
        lineOverlay.setDefaults()
        multiply.setDefaults()
        inputLevels = (posterize.value(forKey: "inputLevels") as? Float) ?? 6
        inputEdgeIntensity = (lineOverlay.value(forKey: "inputEdgeIntensity") as? Float) ?? 1
        inputThreshold = (lineOverlay.value(forKey: "inputThreshold") as? Float) ?? 0.1
    }

    func apply(to image: CIImage) -> CIImage {
        posterize.setValue(image, forKey: kCIInputImageKey)
        posterize.setValue(inputLevels, forKey: "inputLevels")
        guard let posterized = posterize.outputImage else { return image }

        lineOverlay.setValue(image, forKey: kCIInputImageKey)
        lineOverlay.setValue(inputEdgeIntensity, forKey: "inputEdgeIntensity")
        lineOverlay.setValue(inputThreshold, forKey: "inputThreshold")
        guard let lines = lineOverlay.outputImage else { return posterized }

        multiply.setValue(posterized, forKey: kCIInputImageKey)
        multiply.setValue(lines, forKey: kCIInputBackgroundImageKey)
        return multiply.outputImage ?? posterized
    }
}
