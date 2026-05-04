@preconcurrency import AVFoundation
import Combine
import OSLog
import SwiftUI

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZCam", category: "CameraManager")

@MainActor
final class CameraManager: NSObject, ObservableObject {
    // Swift 6 では non-Sendable 型に nonisolated を付けられないため nonisolated(unsafe) を使用。
    // session は sessionQueue 上でのみ操作するため、スレッド安全性は呼び出し側で保証する。
    nonisolated(unsafe) let session = AVCaptureSession()

    @Published var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var zoomFactor: CGFloat = 1.0

    @AppStorage("flashMode") private var storedFlashMode: Int = AVCaptureDevice.FlashMode.auto.rawValue
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto

    private var currentInput: AVCaptureDeviceInput?

    // AVCaptureSession の操作は Apple 推奨の専用シリアルキューで実行する
    private let sessionQueue = DispatchQueue(label: "com.example.ZCam.sessionQueue")

    override init() {
        super.init()
        flashMode = AVCaptureDevice.FlashMode(rawValue: storedFlashMode) ?? .auto
    }

    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        flashMode = mode
        storedFlashMode = mode.rawValue
        logger.info("フラッシュモード変更: \(mode.rawValue, privacy: .public)")
    }

    func requestAccess() async {
        if authorizationStatus == .authorized {
            await configure()
            start()
            return
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : .denied
        if granted {
            await configure()
            start()
        }
    }

    private func configure() async {
        let input: AVCaptureDeviceInput? = await withCheckedContinuation { continuation in
            sessionQueue.async { [session] in
                guard let device = Self.preferredBackCamera() else {
                    logger.error("背面カメラが見つかりません")
                    continuation.resume(returning: nil)
                    return
                }

                session.beginConfiguration()
                defer { session.commitConfiguration() }

                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    guard session.canAddInput(input) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    session.addInput(input)

                    try device.lockForConfiguration()
                    device.videoZoomFactor = 1.0
                    Self.configureContinuousAuto(device: device)
                    device.unlockForConfiguration()

                    continuation.resume(returning: input)
                } catch {
                    logger.error("カメラの設定に失敗しました: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
        currentInput = input
    }

    private nonisolated static func preferredBackCamera() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        for type in types {
            if let device = AVCaptureDevice.default(type, for: .video, position: .back) {
                logger.info("使用するカメラ: \(device.localizedName, privacy: .public)")
                return device
            }
        }
        return nil
    }

    private nonisolated static func configureContinuousAuto(device: AVCaptureDevice) {
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        } else if device.isFocusModeSupported(.autoFocus) {
            device.focusMode = .autoFocus
        }

        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        }

        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
    }

    func start() {
        guard !session.isRunning else { return }
        sessionQueue.async { [session] in
            session.startRunning()
        }
    }

    func setZoomFactor(_ factor: CGFloat) {
        guard let device = currentInput?.device else {
            zoomFactor = factor
            logger.debug("ズーム倍率: \(factor, privacy: .public)")
            return
        }
        let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        zoomFactor = clamped
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                logger.debug("ズーム倍率: \(clamped, privacy: .public)")
            } catch {
                logger.error("ズーム設定に失敗: \(error.localizedDescription)")
            }
        }
    }

    func setFocusPoint(_ point: CGPoint) {
        guard let device = currentInput?.device else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    } else if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    } else if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                }
                device.unlockForConfiguration()
                logger.debug("フォーカスポイントを設定: \(point.x, privacy: .public), \(point.y, privacy: .public)")
            } catch {
                logger.error("フォーカスポイントの設定に失敗: \(error.localizedDescription)")
            }
        }
    }

    func resetFocusToCenter() {
        setFocusPoint(CGPoint(x: 0.5, y: 0.5))
    }

    func stop() {
        guard session.isRunning else { return }
        sessionQueue.async { [session] in
            session.stopRunning()
        }
    }
}
