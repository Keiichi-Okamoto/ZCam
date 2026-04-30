import AVFoundation
import Combine

@MainActor
final class CameraManager: NSObject, ObservableObject {

    let session = AVCaptureSession()

    @Published var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    private var currentInput: AVCaptureDeviceInput?

    func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = granted ? .authorized : .denied
        if granted {
            await configure()
        }
    }

    private func configure() async {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
            }
        } catch {
            return
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
