@preconcurrency import AVFoundation
import Combine
import CoreImage
import OSLog
import UIKit

nonisolated private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZCam", category: "CameraManager")

@MainActor
final class CameraManager: NSObject, ObservableObject {
    // Swift 6 では non-Sendable 型に nonisolated を付けられないため nonisolated(unsafe) を使用。
    // session は sessionQueue 上でのみ操作するため、スレッド安全性は呼び出し側で保証する。
    nonisolated(unsafe) let session = AVCaptureSession()
    let frameStore = CameraFrameStore()

    @Published var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var sliderValue: CGFloat = 1.0
    @Published var sliderMinZoom: CGFloat = 1.0
    @Published var sliderMaxZoom: CGFloat = 3.0

    @Published var flashMode: AVCaptureDevice.FlashMode = .auto

    private var currentInput: AVCaptureDeviceInput?
    private var hasUltraWide: Bool = false

    // AVCaptureSession の操作は Apple 推奨の専用シリアルキューで実行する
    private let sessionQueue = DispatchQueue(label: "com.example.ZCam.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.example.ZCam.videoOutputQueue")
    private let videoOutput = AVCaptureVideoDataOutput()

    override init() {
        super.init()
        let raw = UserDefaults.standard.integer(forKey: "flashMode")
        flashMode = AVCaptureDevice.FlashMode(rawValue: raw) ?? .auto
    }

    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        flashMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "flashMode")
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
        let result: (AVCaptureDeviceInput?, Bool) = await withCheckedContinuation { continuation in
            sessionQueue.async { [session, videoOutput, videoOutputQueue] in
                guard let device = Self.preferredBackCamera() else {
                    logger.error("背面カメラが見つかりません")
                    continuation.resume(returning: (nil, false))
                    return
                }

                session.beginConfiguration()
                defer { session.commitConfiguration() }

                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    guard session.canAddInput(input) else {
                        continuation.resume(returning: (nil, false))
                        return
                    }
                    session.addInput(input)

                    videoOutput.alwaysDiscardsLateVideoFrames = true
                    videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

                    guard session.canAddOutput(videoOutput) else {
                        continuation.resume(returning: (nil, false))
                        return
                    }
                    session.addOutput(videoOutput)

                    if let connection = videoOutput.connection(with: .video) {
                        if connection.isVideoRotationAngleSupported(90) {
                            connection.videoRotationAngle = 90
                        }
                        if connection.isVideoMirroringSupported {
                            connection.isVideoMirrored = false
                        }
                    }

                    let hasUltraWide = device.isVirtualDevice &&
                        device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }

                    try device.lockForConfiguration()
                    // ultrawide搭載時: slider値の2倍をvideoZoomFactorに設定するため、初期値は2.0
                    device.videoZoomFactor = hasUltraWide ? 2.0 : 1.0
                    Self.configureContinuousAuto(device: device)
                    device.unlockForConfiguration()

                    continuation.resume(returning: (input, hasUltraWide))
                } catch {
                    logger.error("カメラの設定に失敗しました: \(error.localizedDescription)")
                    continuation.resume(returning: (nil, false))
                }
            }
        }
        currentInput = result.0
        hasUltraWide = result.1
        sliderMinZoom = result.1 ? 0.5 : 1.0
        sliderMaxZoom = 3.0
        sliderValue = 1.0
    }

    private nonisolated static func preferredBackCamera() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
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
        #if targetEnvironment(simulator)
        loadSimulatorDummyFrame()
        #else
        sessionQueue.async { [session] in
            session.startRunning()
        }
        #endif
    }

    #if targetEnvironment(simulator)
    private func loadSimulatorDummyFrame() {
        guard let uiImage = UIImage(named: "simulator_dummy"),
              let cgImage = uiImage.cgImage else { return }
        frameStore.update(CIImage(cgImage: cgImage))
    }
    #endif

    func setZoomFactor(_ factor: CGFloat) {
        // デバイス有無に関わらずスライダー値を保持（シミュレータでの拡大縮小表示に使用）
        sliderValue = factor
        guard let device = currentInput?.device else {
            logger.debug("ズームスライダー値(デバイスなし): \(factor, privacy: .public)")
            return
        }
        // ultrawide搭載時はslider値の2倍をvideoZoomFactorに設定
        let rawFactor = hasUltraWide ? factor * 2.0 : factor
        let clamped = min(max(rawFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                logger.debug("ズーム倍率(slider=\(factor, privacy: .public), zoom=\(clamped, privacy: .public))")
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

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameStore.update(CIImage(cvPixelBuffer: pixelBuffer))
    }
}
