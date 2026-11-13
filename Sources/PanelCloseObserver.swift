import AppKit
import SwiftUI

/// Calls `onClose` when the panel closes. The menu bar panel stops being the key window
/// as soon as you click elsewhere, which is the moment it disappears.
struct PanelCloseObserver: NSViewRepresentable {
    let onClose: () -> Void

    func makeNSView(context: Context) -> ObserverView { ObserverView(onClose: onClose) }
    func updateNSView(_ view: ObserverView, context: Context) { view.onClose = onClose }

    final class ObserverView: NSView {
        var onClose: () -> Void
        private var token: NSObjectProtocol?

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            token = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in self?.onClose() }
        }

        private func stopObserving() {
            if let token { NotificationCenter.default.removeObserver(token) }
            token = nil
        }

        deinit { stopObserving() }
    }
}
