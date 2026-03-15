import AppKit
import SwiftUI

@MainActor @objc public class OakRenameField: NSObject {
    @objc public weak var delegate: OakRenameFieldDelegate?

    private let theme: OakThemeEnvironment
    private var panel: NSPanel?

    @objc public init(theme: OakThemeEnvironment) {
        self.theme = theme
    }

    /// `screenPoint` is already in screen coordinates (from positionForWindowUnderCaret)
    @objc public func show(in parentView: NSView, at screenPoint: NSPoint, placeholder: String) {
        dismiss()

        guard let parentWindow = parentView.window else { return }

        let view = RenameFieldView(
            theme: theme,
            text: placeholder,
            onConfirm: { [weak self] newName in
                guard let self else { return }
                self.delegate?.renameField(self, didConfirmWithName: newName)
                self.dismiss()
            },
            onDismiss: { [weak self] in
                guard let self else { return }
                self.dismiss()
                self.delegate?.renameFieldDidDismiss(self)
            }
        )

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame.size = hostingView.fittingSize

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.contentView = hostingView
        p.backgroundColor = NSColor.controlBackgroundColor
        p.hasShadow = true
        p.level = .floating
        p.isReleasedWhenClosed = false

        // screenPoint is already in screen coords — use directly
        p.setFrameTopLeftPoint(screenPoint)

        parentWindow.addChildWindow(p, ordered: .above)
        p.makeKeyAndOrderFront(nil)
        self.panel = p

        // Focus the text field after a brief delay
        DispatchQueue.main.async {
            p.makeFirstResponder(p.contentView?.subviews.first)
        }
    }

    @objc public func dismiss() {
        if let p = panel {
            p.parent?.removeChildWindow(p)
            p.orderOut(nil)
            panel = nil
        }
    }

    @objc public var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
