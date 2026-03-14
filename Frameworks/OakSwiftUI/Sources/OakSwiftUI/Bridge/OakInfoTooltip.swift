import AppKit
import SwiftUI

// ViewModel to hold the current content
class TooltipViewModel: ObservableObject {
    @Published var content: OakTooltipContent
    
    init(content: OakTooltipContent) {
        self.content = content
    }
}

// Root view that observes the view model
struct TooltipRootView: View {
    @ObservedObject var viewModel: TooltipViewModel
    
    var body: some View {
        TooltipContentView(content: viewModel.content)
    }
}

@MainActor @objc public class OakInfoTooltip: NSObject, NSPopoverDelegate {
    @objc public weak var delegate: OakInfoTooltipDelegate?

    private let popover: NSPopover
    private let theme: OakThemeEnvironment
    private let viewModel: TooltipViewModel

    @objc public init(theme: OakThemeEnvironment) {
        self.theme = theme
        // Initialize with empty content
        let emptyContent = OakTooltipContent(body: NSAttributedString())
        self.viewModel = TooltipViewModel(content: emptyContent)
        
        self.popover = NSPopover()
        self.popover.animates = false // Disable animation for performance
        self.popover.behavior = .semitransient
        
        super.init()
        
        // Create the root view with environment object
        let rootView = TooltipRootView(viewModel: viewModel)
            .environmentObject(theme)
        
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = [.preferredContentSize]
        
        self.popover.contentViewController = hostingController
        self.popover.delegate = self
    }

    @objc public func show(in view: NSView, at rect: NSRect, content: OakTooltipContent, preferredEdge edge: NSRectEdge) {
        // Update content model
        viewModel.content = content
        
        // Force layout update for the new content
        if let controller = popover.contentViewController {
            controller.view.layoutSubtreeIfNeeded()
        }
        
        // Show or move popover
        if popover.isShown {
            popover.positioningRect = rect
        } else {
            popover.show(relativeTo: rect, of: view, preferredEdge: edge)
        }
    }
    
    @objc public func show(in view: NSView, at rect: NSRect, content: OakTooltipContent) {
        show(in: view, at: rect, content: content, preferredEdge: .maxY)
    }

    @objc public func dismiss() {
        if popover.isShown {
            popover.close()
        }
    }

    @objc public func reposition(to rect: NSRect) {
        if popover.isShown {
            popover.positioningRect = rect
        }
    }

    @objc public var isVisible: Bool {
        popover.isShown
    }

    nonisolated public func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            delegate?.infoTooltipDidDismiss(self)
        }
    }
}
