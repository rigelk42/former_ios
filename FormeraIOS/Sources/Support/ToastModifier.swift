import SwiftUI

/// Transient, auto-dismissing banner for a user-triggered action failure
/// (save/create/delete/purchase) -- pairs with apiErrorMessage(_:). Distinct
/// from the ContentUnavailableView pattern list/detail screens use for "this
/// screen has no content to show" load failures, which should stay visible
/// until the underlying load succeeds rather than auto-dismiss.
private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.red, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .shadow(radius: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { self.message = nil }
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(4))
                        if !Task.isCancelled { self.message = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
