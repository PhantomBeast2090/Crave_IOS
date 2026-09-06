import AVFoundation
import SwiftUI

/// Vendor QR scanner (mirrors Android QRScannerScreen): native camera scan
/// with manual-token fallback. Tokens verify via `verify_pickup_token` —
/// orders are never marked picked up locally.
struct VendorScannerView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: VendorScannerViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                GagLoadingView(message: "Preparing scanner…")
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Scan Pickup QR")
        .navigationBarTitleDisplayMode(.inline)
        .task { await setupViewModel() }
    }

    private func setupViewModel() async {
        guard viewModel == nil else { return }
        let vm = VendorScannerViewModel(repository: appState.repository.orders)
        self.viewModel = vm
        vm.checkPermission()
    }

    @ViewBuilder
    private func content(viewModel: VendorScannerViewModel) -> some View {
        switch viewModel.state {
        case .verified(let orderNumber):
            VStack(spacing: GagShapes.spacingL) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(GagColors.success)
                Text("Order Verified!")
                    .font(GagTypography.titleMedium)
                    .foregroundStyle(GagColors.success)
                Text("Order: \(orderNumber)")
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.onSurface)
                Text("Hand over to student.")
                    .font(GagTypography.bodySmall)
                    .foregroundStyle(GagColors.onSurfaceVariant)
                GagButton(title: "Scan Next", action: { viewModel.reset() })
                    .padding(.horizontal, GagShapes.spacingXL)
                Spacer()
            }
        case .error(let message):
            VStack(spacing: GagShapes.spacingL) {
                Spacer()
                Image(systemName: "exclamationmark.octagon")
                    .font(.system(size: 64))
                    .foregroundStyle(GagColors.error)
                Text(message)
                    .font(GagTypography.bodyMedium)
                    .foregroundStyle(GagColors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, GagShapes.spacingXL)
                GagButton(title: "Scan Again", action: { viewModel.reset() })
                    .padding(.horizontal, GagShapes.spacingXL)
                Spacer()
            }
        case .idle, .verifying:
            scannerContent(viewModel: viewModel)
        }
    }

    private func scannerContent(viewModel: VendorScannerViewModel) -> some View {
        @Bindable var bindable = viewModel
        return VStack(spacing: GagShapes.spacingL) {
            if viewModel.cameraAuthorized {
                ZStack {
                    QRScannerRepresentable { code in
                        Task { await viewModel.verify(token: code) }
                    }
                    .frame(height: 320)
                    .clipShape(GagShapes.cornerRadius(GagShapes.radiusLarge))

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GagColors.brandOrange, lineWidth: 3)
                        .frame(width: 220, height: 220)
                }
                .padding(.horizontal, GagShapes.spacingL)

                if case .verifying = viewModel.state {
                    HStack {
                        ProgressView().tint(GagColors.brandOrange)
                        Text("Verifying token…")
                            .font(GagTypography.bodyMedium)
                            .foregroundStyle(GagColors.onSurfaceVariant)
                    }
                } else {
                    Text("Point the camera at the student's QR code")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                }
            } else {
                VStack(spacing: GagShapes.spacingS) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(GagColors.onSurfaceDim)
                    Text("Camera permission is required to scan QR codes.")
                        .font(GagTypography.bodyMedium)
                        .foregroundStyle(GagColors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                    Button("Check Again") { viewModel.checkPermission() }
                        .font(GagTypography.labelLarge)
                        .foregroundStyle(GagColors.brandOrange)
                }
                .padding(GagShapes.spacingXL)
            }

            VStack(spacing: GagShapes.spacingS) {
                GagTextField(
                    title: "Or enter the token manually",
                    text: $bindable.manualToken,
                    placeholder: "Paste QR token",
                    autocapitalization: .never
                )
                GagButton(
                    title: "Validate Token",
                    isEnabled: !viewModel.manualToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: { Task { await viewModel.verify(token: viewModel.manualToken) } }
                )
            }
            .padding(.horizontal, GagShapes.spacingL)

            Spacer()
        }
        .padding(.top, GagShapes.spacingL)
    }
}

// MARK: - AVCapture QR scanner bridge

/// Native camera QR scanner. Fires `onCode` once per distinct value.
struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        QRScannerViewController(onCode: onCode)
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let onCode: (String) -> Void
    private var session: AVCaptureSession?
    private var lastCode: String?

    init(onCode: @escaping (String) -> Void) {
        self.onCode = onCode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.clipsToBounds = true
        startSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.forEach { layer in
            if let preview = layer as? AVCaptureVideoPreviewLayer {
                preview.frame = view.bounds
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.stopRunning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if session?.isRunning == false {
            lastCode = nil
            session?.startRunning()
        }
    }

    private func startSession() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        let session = AVCaptureSession()
        guard session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        self.session = session
        session.startRunning()
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue,
              !code.isEmpty, code != lastCode
        else { return }
        lastCode = code
        session?.stopRunning()
        onCode(code)
    }
}
