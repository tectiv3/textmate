import AppKit
import SwiftUI
import Combine

@MainActor
@objc public class OakNotificationManager: NSObject {
	@objc public static let shared = OakNotificationManager()

	private let model = ToastViewModel()
	private var windowController: NSWindowController?
	private var cancellables = Set<AnyCancellable>()

	private override init() {}

	@objc public func show(message: String, type: Int) {
		var controlAndWhitespace = CharacterSet.whitespacesAndNewlines
		controlAndWhitespace.formUnion(.controlCharacters)
		controlAndWhitespace.insert(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}")
		let trimmed = message.trimmingCharacters(in: controlAndWhitespace)
		guard !trimmed.isEmpty else { return }

		let toastType: ToastType
		switch type {
		case 1: toastType = .error
		case 2: toastType = .warning
		case 3: toastType = .info
		case 4: toastType = .success
		default: toastType = .info
		}
		self.ensureWindow()
		self.model.show(message: trimmed, type: toastType)
		// Force the panel to redraw — borderless NSHostingView can go stale after idle
		self.windowController?.window?.orderFrontRegardless()
		self.windowController?.window?.displayIfNeeded()
	}

	private func ensureWindow() {
		if windowController != nil { return }

		let view = NotificationView(model: model)
		let hostingView = NSHostingView(rootView: view)

		let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 80),
		                     styleMask: [.borderless, .nonactivatingPanel],
		                     backing: .buffered, defer: false)
		window.isOpaque = false
		window.backgroundColor = .clear
		window.level = .floating
		window.hidesOnDeactivate = true
		window.collectionBehavior = [.fullScreenAuxiliary]
		window.ignoresMouseEvents = true
		window.hasShadow = false

		if let screen = NSScreen.main {
			let screenRect = screen.visibleFrame
			let x = screenRect.midX - 250
			let y = screenRect.origin.y + 40
			window.setFrameOrigin(NSPoint(x: x, y: y))
		}

		window.contentView = hostingView
		windowController = NSWindowController(window: window)
		windowController?.showWindow(nil)

		model.$currentToast
			.receive(on: DispatchQueue.main)
			.sink { [weak window] toast in
				window?.ignoresMouseEvents = (toast == nil)
			}
			.store(in: &cancellables)
	}
}
