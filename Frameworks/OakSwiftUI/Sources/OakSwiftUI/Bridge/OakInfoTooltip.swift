import AppKit
import SwiftUI

@MainActor @objc public class OakInfoTooltip: NSObject, NSPopoverDelegate {
    @objc public weak var delegate: OakInfoTooltipDelegate?

    private var popover: NSPopover?
    private let theme: OakThemeEnvironment

    @objc public init(theme: OakThemeEnvironment) {
        self.theme = theme
        super.init()
    }

    @objc public func show(in view: NSView, at rect: NSRect, content: OakTooltipContent) {
        show(in: view, at: rect, content: content, preferredEdge: .maxY)
    }

    @objc public func show(in view: NSView, at rect: NSRect, content: OakTooltipContent, preferredEdge edge: NSRectEdge) {
        dismiss()

        let tooltipView = TooltipContentView(content: content)
            .environmentObject(theme)

        let hostingController = NSHostingController(rootView: tooltipView)

        let pop = NSPopover()
        pop.contentViewController = hostingController
        pop.behavior = .semitransient
        pop.delegate = self
        pop.show(relativeTo: rect, of: view, preferredEdge: edge)
        self.popover = pop
    }

    @objc public func dismiss() {
        popover?.performClose(nil)
        popover = nil
    }

    @objc public func reposition(to rect: NSRect) {
        popover?.positioningRect = rect
    }

    @objc public var isVisible: Bool {
        popover?.isShown ?? false
    }

    nonisolated public func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            popover = nil
            delegate?.infoTooltipDidDismiss(self)
        }
    }
}
