import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum AddressConfigurationLink {
    static func make(for uploadURL: String) -> URL? {
        guard let target = URL(string: uploadURL),
              let scheme = target.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              target.host != nil
        else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "androidsync"
        components.host = "configure"
        components.queryItems = [URLQueryItem(name: "url", value: uploadURL)]
        return components.url
    }
}

enum AddressQRCodeRenderer {
    static func image(for payload: String, dimension: CGFloat = 220) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let extent = output.extent.integral
        let scale = max(1, floor(dimension / max(extent.width, extent.height)))
        let scaled = output.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: dimension, height: dimension)
        )
    }
}
