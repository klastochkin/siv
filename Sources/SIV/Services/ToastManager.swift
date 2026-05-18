import Foundation
import SwiftUI

struct Toast: Identifiable {
    let id = UUID()
    let message: String
}

@MainActor
class ToastManager: ObservableObject {
    @Published var toasts: [Toast] = []

    /// Height in points for each toast banner (used to decide when to trim overflow).
    static let estimatedHeight: CGFloat = 60
    static let spacing: CGFloat = 8
    static let dismissAfterSeconds: Double = 15

    private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    func show(_ message: String) {
        let toast = Toast(message: message)
        withAnimation(.easeOut(duration: 0.25)) {
            toasts.append(toast)
        }
        scheduleDismiss(for: toast.id)
    }

    func dismiss(id: UUID) {
        dismissTasks[id]?.cancel()
        dismissTasks.removeValue(forKey: id)
        withAnimation(.easeIn(duration: 0.2)) {
            toasts.removeAll { $0.id == id }
        }
    }

    /// Call from the overlay view whenever its height or the toast count changes.
    /// Removes the oldest toasts so all remaining ones fit within `availableHeight`.
    func trimToFit(availableHeight: CGFloat) {
        let perToast = Self.estimatedHeight + Self.spacing
        let maxVisible = max(1, Int(availableHeight / perToast))
        while toasts.count > maxVisible {
            let oldest = toasts[0]
            dismissTasks[oldest.id]?.cancel()
            dismissTasks.removeValue(forKey: oldest.id)
            withAnimation(.easeIn(duration: 0.2)) {
                toasts.removeFirst()
            }
        }
    }

    private func scheduleDismiss(for id: UUID) {
        let task = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(Self.dismissAfterSeconds * 1_000_000_000))
                self?.dismiss(id: id)
            } catch {}
        }
        dismissTasks[id] = task
    }
}
