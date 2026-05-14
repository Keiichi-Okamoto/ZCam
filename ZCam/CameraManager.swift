import AudioToolbox
@preconcurrency import AVFoundation
import Combine
import CoreImage
import OSLog
import Photos
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
    @Published var isSessionReady: Bool = false
    @Published var showsFlashUnavailableAlert: Bool = false

    private var currentInput: AVCaptureDeviceInput?
    private var hasUltraWide: Bool = false

    // AVCaptureSession の操作は Apple 推奨の専用シリアルキューで実行する
    private let sessionQueue = DispatchQueue(label: "com.example.ZCam.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.example.ZCam.videoOutputQueue")
    // session と同様に sessionQueue 上でのみ操作するため nonisolated(unsafe) で宣言
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    private let ciContext = CIContext()
    nonisolated(unsafe) private var pendingFilterSnapshot: FilterPipeline.Snapshot?

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
        } else {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationStatus = granted ? .authorized : .denied
            if granted {
                await configure()
                start()
            }
        }
        _ = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }

    private func configure() async {
        let result: (AVCaptureDeviceInput?, Bool) = await withCheckedContinuation { continuation in
            sessionQueue.async { [session, videoOutput, videoOutputQueue, photoOutput] in
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

                    #if !targetEnvironment(simulator)
                    if session.canAddOutput(photoOutput) {
                        session.addOutput(photoOutput)
                    }
                    #endif

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
        isSessionReady = result.0 != nil
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
              let cgImage = uiImage.cgImage else {
            logger.error("simulator_dummy 画像が見つかりません")
            return
        }
        frameStore.update(CIImage(cgImage: cgImage))
        isSessionReady = true
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
        let normalizedPoint = CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
        guard let device = currentInput?.device else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = normalizedPoint
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    } else if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = normalizedPoint
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    } else if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                }
                device.unlockForConfiguration()
                logger.debug("フォーカスポイントを設定: \(normalizedPoint.x, privacy: .public), \(normalizedPoint.y, privacy: .public)")
            } catch {
                logger.error("フォーカスポイントの設定に失敗: \(error.localizedDescription)")
            }
        }
    }

    func resetFocusToCenter() {
        setFocusPoint(CGPoint(x: 0.5, y: 0.5))
    }

    func capturePhoto(filterSnapshot: FilterPipeline.Snapshot) {
        if flashMode != .off, currentInput?.device.isFlashAvailable != true {
            showsFlashUnavailableAlert = true
            return
        }
        #if targetEnvironment(simulator)
        AudioServicesPlaySystemSound(1108)
        #else
        pendingFilterSnapshot = filterSnapshot
        let mode = flashMode
        sessionQueue.async { [photoOutput] in
            guard photoOutput.connection(with: .video) != nil else {
                logger.warning("撮影スキップ: photoOutput がセッションに未接続")
                return
            }
            let settings = AVCapturePhotoSettings()
            if photoOutput.supportedFlashModes.contains(mode) {
                settings.flashMode = mode
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
        #endif
    }

    func stop() {
        guard session.isRunning else { return }
        sessionQueue.async { [session] in
            session.stopRunning()
        }
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        if let error {
            logger.error("撮影に失敗しました: \(error.localizedDescription)")
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let rawImage = CIImage(data: data) else {
            logger.error("撮影データの取得に失敗")
            return
        }

        let snapshot = pendingFilterSnapshot
        let filtered = snapshot.map { Self.applyFilters(to: rawImage, snapshot: $0) } ?? rawImage

        guard let cgImage = ciContext.createCGImage(filtered, from: filtered.extent) else {
            logger.error("CGImage の生成に失敗")
            return
        }
        let uiImage = UIImage(cgImage: cgImage)

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
        }, completionHandler: { success, error in
            if success {
                logger.info("フォトライブラリへの保存完了")
            } else if let error {
                logger.error("フォトライブラリへの保存失敗: \(error.localizedDescription)")
            }
        })
    }

    nonisolated private static func applyFilters(to image: CIImage,
                                                 snapshot: FilterPipeline.Snapshot) -> CIImage {
        guard let posterize = CIFilter(name: "CIColorPosterize"),
              let lineOverlay = CIFilter(name: "CILineOverlay"),
              let multiply = CIFilter(name: "CIMultiplyBlendMode") else {
            return image
        }
        posterize.setValue(image, forKey: kCIInputImageKey)
        posterize.setValue(snapshot.inputLevels, forKey: "inputLevels")
        guard let posterized = posterize.outputImage else { return image }

        lineOverlay.setValue(image, forKey: kCIInputImageKey)
        lineOverlay.setValue(snapshot.inputEdgeIntensity, forKey: "inputEdgeIntensity")
        lineOverlay.setValue(snapshot.inputThreshold, forKey: "inputThreshold")
        guard let lines = lineOverlay.outputImage else { return posterized }

        multiply.setValue(posterized, forKey: kCIInputImageKey)
        multiply.setValue(lines, forKey: kCIInputBackgroundImageKey)
        return multiply.outputImage ?? posterized
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
