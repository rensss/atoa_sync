import AppKit
import SwiftUI

struct AddressQRCodeButton: View {
    @Bindable var model: AppModel
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "qrcode")
        }
        .buttonStyle(ToolbarIconButtonStyle())
        .accessibilityLabel(model.text(.showAddressQRCode))
        .help(model.text(.showAddressQRCode))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            qrCodeContent
        }
    }

    private var configurationLink: URL? {
        AddressConfigurationLink.make(for: model.uploadURL)
    }

    @ViewBuilder
    private var qrCodeContent: some View {
        VStack(spacing: Theme.spacingM) {
            Text(model.text(.showAddressQRCode))
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text(model.text(.scanAddressQRCode))
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            if let configurationLink,
               let image = AddressQRCodeRenderer.image(
                   for: configurationLink.absoluteString
               ) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL))
            } else {
                ContentUnavailableView(
                    model.text(.addressQRCodeUnavailable),
                    systemImage: "qrcode"
                )
                .frame(width: 220, height: 220)
            }
            Text(model.uploadURL)
                .font(.caption.monospaced())
                .foregroundStyle(Theme.textSecondary)
                .textSelection(.enabled)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button(model.text(.copyUploadAddress)) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.uploadURL, forType: .string)
            }
        }
        .padding(Theme.spacingL)
        .background(Theme.bgRaised)
    }
}
