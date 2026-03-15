import AppKit
import SwiftUI

private let kFrameKey = "OakLSPLogWindow.frame"

@MainActor
@objc public class OakLogPanel: NSObject {
	@objc public static let shared = OakLogPanel()

	private let model = LogViewModel()
	private var windowController: NSWindowController?
	private var frameObservers: [Any] = []

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
		if windowController == nil || windowController?.window == nil {
			let hostingView = NSHostingView(rootView: LogView(model: model))

			let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
			                      styleMask: [.titled, .closable, .miniaturizable, .resizable],
			                      backing: .buffered, defer: false)
			window.title = "LSP Log"
			window.isReleasedWhenClosed = false
			window.contentView = hostingView
			window.contentMinSize = NSSize(width: 400, height: 300)

			if let frameString = UserDefaults.standard.string(forKey: kFrameKey) {
				window.setFrame(NSRectFromString(frameString), display: false)
			} else {
				window.center()
			}

			frameObservers.forEach { NotificationCenter.default.removeObserver($0) }
			frameObservers = [
				NotificationCenter.default.addObserver(
					forName: NSWindow.didResizeNotification, object: window, queue: .main
				) { [weak window] _ in
					guard let window, window.isVisible else { return }
					UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: kFrameKey)
				},
				NotificationCenter.default.addObserver(
					forName: NSWindow.didMoveNotification, object: window, queue: .main
				) { [weak window] _ in
					guard let window, window.isVisible else { return }
					UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: kFrameKey)
				}
			]

			windowController = NSWindowController(window: window)
		}

		windowController?.showWindow(nil)
		windowController?.window?.makeKeyAndOrderFront(nil)
	}
}
