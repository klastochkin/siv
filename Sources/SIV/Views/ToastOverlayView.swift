import SwiftUI

/// A single toast banner shown in the top-right corner.
struct ToastBannerView: View {
    let toast: Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 15))

            Text(toast.message)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }
}

/// Overlay that stacks toasts in the top-right corner.
/// New toasts are added below existing ones.
/// When toasts would overflow the available height, the oldest is removed first.
struct ToastOverlayView: View {
    @ObservedObject var manager: ToastManager

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .trailing, spacing: ToastManager.spacing) {
                ForEach(manager.toasts) { toast in
                    ToastBannerView(toast: toast) {
                        manager.dismiss(id: toast.id)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .onChange(of: manager.toasts.count) { _ in
                let usable = geo.size.height - 32
                manager.trimToFit(availableHeight: usable)
            }
            .onChange(of: geo.size.height) { height in
                manager.trimToFit(availableHeight: height - 32)
            }
        }
        .allowsHitTesting(!manager.toasts.isEmpty)
    }
}
