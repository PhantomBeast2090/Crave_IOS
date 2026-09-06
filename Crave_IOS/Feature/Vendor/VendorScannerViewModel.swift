import AVFoundation
import Foundation
import Observation

/// QR verification state machine (mirrors Android QRScannerScreen):
/// permission → scan/manual entry → verify_pickup_token → verified order.
@MainActor
@Observable
final class VendorScannerViewModel {
    enum State: Equatable {
        case idle
        case verifying
        case verified(orderNumber: String)
        case error(message: String)
    }

    private(set) var state: State = .idle
    private(set) var cameraAuthorized = false
    var manualToken = ""

    private let repository: OrderRepository

    init(repository: OrderRepository) {
        self.repository = repository
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in self?.cameraAuthorized = granted }
            }
        default:
            cameraAuthorized = false
        }
    }

    func verify(token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if case .verifying = state { return }
        state = .verifying
        do {
            let order = try await repository.confirmPickup(qrToken: trimmed)
            state = .verified(orderNumber: order.orderNumber)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
        manualToken = ""
    }
}
