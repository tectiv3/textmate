import AppKit
import SwiftUI
import Combine

private class KeyablePanel: NSPanel {
	override var canBecomeKey: Bool { true }
}

@MainActor @objc public class OakCommandPalette: NSObject, NSWindowDelegate {
	@objc public weak var delegate: OakCommandPaletteDelegate?

	private let theme: OakThemeEnvironment
	private var panel: KeyablePanel?
	private var viewModel: CommandPaletteViewModel?
	private var cancellables = Set<AnyCancellable>()

	@objc public init(theme: OakThemeEnvironment) {
		self.theme = theme
		super.init()
	}

	@objc public func show(in parentWindow: NSWindow, items: [OakCommandPaletteItem]) {
		dismiss()

		let vm = CommandPaletteViewModel()
		vm.setItems(items, forMode: .recentProjects)

		let commands = items.filter {
			$0.category == .menuAction || $0.category == .bundleCommand
		}
		vm.setItems(commands, forMode: .commands)

		let projects = items.filter { $0.category == .recentProject }
		vm.setItems(projects, forMode: .recentProjects)

		vm.onItemSelected = { [weak self] item in
			self?.dismiss()
			self?.delegate?.commandPaletteDidSelectItem(item)
		}
		vm.onDismiss = { [weak self] in
			self?.dismiss()
		}
		vm.onModeSwitch = { [weak self] mode in
			self?.delegate?.commandPaletteRequestItems(forMode: mode.intValue) ?? []
		}

		self.viewModel = vm

		let rootView = CommandPaletteView(viewModel: vm)
			.environmentObject(theme)

		let hostingView = NSHostingView(rootView: rootView)

		let parentFrame = parentWindow.frame
		let panelWidth = min(max(parentFrame.width * 0.5, 400), 700)
		let panelHeight: CGFloat = 400

		let panelX = parentFrame.origin.x + (parentFrame.width - panelWidth) / 2
		let panelY = parentFrame.origin.y + parentFrame.height * 0.75 - panelHeight / 2

		let panelFrame = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

		let p = KeyablePanel(
			contentRect: panelFrame,
			styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered,
			defer: false
		)
		p.level = .floating
		p.isOpaque = false
		p.backgroundColor = .clear
		p.hasShadow = true
		p.contentView = hostingView
		p.delegate = self

		parentWindow.addChildWindow(p, ordered: .above)
		p.makeKeyAndOrderFront(nil)

		self.panel = p
	}

	@objc public func loadFrecencyData(_ data: NSDictionary) {
		var entries: [String: FrecencyEntry] = [:]
		for case let (key as String, value as NSDictionary) in data {
			let count = (value["count"] as? Int) ?? 0
			let lastUsed = (value["lastUsed"] as? TimeInterval) ?? 0
			entries[key] = FrecencyEntry(count: count, lastUsed: lastUsed)
		}
		viewModel?.loadFrecency(entries)
	}

	@objc public func dismiss() {
		guard let p = panel else { return }
		p.parent?.removeChildWindow(p)
		p.orderOut(nil)
		panel = nil
		viewModel = nil
		cancellables.removeAll()
		delegate?.commandPaletteDidDismiss()
	}

	@objc public var isVisible: Bool {
		panel?.isVisible ?? false
	}

	// MARK: - NSWindowDelegate

	nonisolated public func windowDidResignKey(_ notification: Notification) {
		MainActor.assumeIsolated {
			dismiss()
		}
	}
}
