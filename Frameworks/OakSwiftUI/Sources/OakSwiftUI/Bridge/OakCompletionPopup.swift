import AppKit
import SwiftUI

@MainActor @objc public class OakCompletionPopup: NSObject {
    @objc public weak var delegate: OakCompletionPopupDelegate?

    private var window: NSWindow?
    private var viewModel: CompletionViewModel?
    private let theme: OakThemeEnvironment

    @objc public init(theme: OakThemeEnvironment) {
        self.theme = theme
        super.init()
    }

    @objc public func show(in parentView: NSView, at point: NSPoint, items: [OakCompletionItem]) {
        // Tear down previous window without firing delegate callback
        if let w = window {
            w.parent?.removeChildWindow(w)
            w.orderOut(nil)
            window = nil
            viewModel = nil
        }

        let vm = CompletionViewModel()
        vm.setItems(items)
        self.viewModel = vm

        let listView = CompletionListView(viewModel: vm)
            .environmentObject(theme)

        let hostingView = NSHostingView(rootView: listView)

        let rowHeight = max(theme.fontSize * 1.8, 22)
        let itemCount = min(items.count, 12)
        let height = CGFloat(itemCount) * rowHeight + 8
        let maxLabelWidth = items.prefix(50).map { ($0.label as NSString).size(withAttributes: [.font: theme.font]).width }.max() ?? 200
        let width = min(max(maxLabelWidth + 120, 250), 600)

        let screenPoint = parentView.window?.convertPoint(toScreen:
            parentView.convert(point, to: nil)) ?? point

        var origin = NSPoint(x: screenPoint.x, y: screenPoint.y - height)
        if let screen = NSScreen.main, origin.y < screen.visibleFrame.minY {
            origin.y = screenPoint.y + 20
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hostingView

        panel.orderFront(nil)
        parentView.window?.addChildWindow(panel, ordered: .above)
        self.window = panel
    }

    @objc public func updateFilter(_ text: String) {
        viewModel?.updateFilter(text)
        resizePanelToFit()
    }

    private func resizePanelToFit() {
        guard let w = window, let vm = viewModel else { return }
        let rowHeight = max(theme.fontSize * 1.8, 22)
        let itemCount = min(vm.filteredItems.count, 12)
        let newHeight = CGFloat(itemCount) * rowHeight + 8
        var frame = w.frame
        let delta = newHeight - frame.height
        frame.origin.y -= delta
        frame.size.height = newHeight
        w.setFrame(frame, display: true, animate: false)
    }

    @objc public func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let vm = viewModel else { return false }

        switch event.keyCode {
        case 125: // down arrow
            vm.selectNext()
            return true
        case 126: // up arrow
            vm.selectPrevious()
            return true
        case 36: // return
            if let item = vm.selectedItem {
                delegate?.completionPopup(self, didSelectItem: item)
                dismiss()
            }
            return true
        case 48: // tab
            if let item = vm.selectedItem {
                delegate?.completionPopup(self, didSelectItem: item)
                dismiss()
            }
            return true
        case 53: // escape
            dismiss()
            return true
        default:
            return false
        }
    }

    @objc public func dismiss() {
        if let w = window {
            w.parent?.removeChildWindow(w)
            w.orderOut(nil)
            window = nil
            viewModel = nil
            delegate?.completionPopupDidDismiss(self)
        }
    }

    @objc public var isVisible: Bool {
        window?.isVisible ?? false
    }
}
