import CoreImage
import SwiftUI
import UIKit

/// QR code rendered natively with CoreImage (no third-party dependency).
/// Encodes the backend pickup token verbatim — never generates tokens locally.
struct QRCodeView: View {
    let content: String
    var size: CGFloat = 220

    var body: some View {
        Group {
            if content.isEmpty {
                placeholder
            } else if let image = generateQRCode(from: content) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        ZStack {
            GagColors.surfaceVariant
            Image(systemName: "qrcode")
                .font(.system(size: 48))
                .foregroundStyle(GagColors.onSurfaceDim)
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
