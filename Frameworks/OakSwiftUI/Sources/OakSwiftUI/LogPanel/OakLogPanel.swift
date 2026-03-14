import AppKit
import SwiftUI

@MainActor
@objc public class OakLogPanel: NSObject {
	@objc public static let shared = OakLogPanel()

	private let model = LogViewModel()
	private var windowController: NSWindowController?

	private override init() {}

	@objc public func log(message: String, level: Int, source: String) {
		self.model.add(message: message, level: level, source: source)
	}

	@objc public func show() {
		self.showPanel()
	}

	@objc public func toggle() {
		if let window = self.windowController?.window, window.isVisible {
			window.close()
		} else {
			self.showPanel()
		}
	}

	private func showPanel() {
		if windowController == nil {
			let view = LogView(model: model)
			let hostingController = NSHostingController(rootView: view)

			let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
			                      styleMask: [.titled, .closable, .miniaturizable, .resizable],
			                      backing: .buffered, defer: false)
			window.title = "LSP Log"
			window.center()
			window.setFrameAutosaveName("OakLSPLogWindow")
			window.contentViewController = hostingController
			window.contentMinSize = NSSize(width: 400, height: 300)

			windowController = NSWindowController(window: window)
		}

		windowController?.showWindow(nil)
		windowController?.window?.makeKeyAndOrderFront(nil)
	}
}
