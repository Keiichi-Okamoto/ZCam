import AVFoundation
import Combine
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ZCam", category: "CameraManager")

@MainActor
final class CameraManager: NSObject, ObservableObject {

    nonisolated let session = AVCaptureSession()

    @Published var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    private var currentInput: AVCaptureDeviceInput?

    func requestAccess() async {
        if authorizationStatus == .authorized {
            await configure()
            return
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : .denied
        if granted {
            await configure()
        }
    }

    private nonisolated func configure() async {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            logger.error("背面広角カメラが見つかりません")
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                await MainActor.run { currentInput = input }
            }

            try device.lockForConfiguration()
            #if os(iOS)
            device.videoZoomFactor = device.minAvailableVideoZoomFactor
            #endif
            device.unlockForConfiguration()
        } catch {
            logger.error("カメラの設定に失敗しました: \(error.localizedDescription)")
        }
    }

    func start() {
        guard !session.isRunning else { return }
        Task.detached { [session] in
            session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        Task.detached { [session] in
            session.stopRunning()
        }
    }
}
