import Combine
import SwiftUI
import UIKit

@MainActor
final class OrientationObserver: ObservableObject {
    @Published var orientation: UIDeviceOrientation = .portrait

    nonisolated(unsafe) private var observer: NSObjectProtocol?

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let next = UIDevice.current.orientation
            // Portrait / LandscapeLeft / LandscapeRight のみ採用
            switch next {
            case .portrait, .landscapeLeft, .landscapeRight:
                self?.orientation = next
            default:
                break
            }
        }
        self.orientation = UIDevice.current.orientation
    }

    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// UI に適用する回転角（ボタン・スライダー共通）
    var rotationAngle: Angle {
        switch orientation {
        case .landscapeLeft:  return .degrees(90)
        case .landscapeRight: return .degrees(-90)
        default:              return .degrees(0)
        }
    }

    var isLandscapeLeft: Bool { orientation == .landscapeLeft }
    var isLandscapeRight: Bool { orientation == .landscapeRight }
    var isLandscape: Bool { isLandscapeLeft || isLandscapeRight }
}
