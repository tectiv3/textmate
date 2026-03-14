import AppKit
import SwiftUI

@objc public class OakLogPanel: NSObject, @unchecked Sendable {
    @objc public static let shared = OakLogPanel()
    
    private let model = LogViewModel()
    private var windowController: NSWindowController?
    
    private override init() {}
    
    @objc public func log(message: String, level: Int, source: String) {
        Task { @MainActor in
            self.model.add(message: message, level: level, source: source)
        }
    }
    
    @objc public func show() {
        Task { @MainActor in
            self.showOnMainThread()
        }
    }
    
    @objc public func toggle() {
        Task { @MainActor in
            if let window = self.windowController?.window, window.isVisible {
                window.close()
            } else {
                self.showOnMainThread()
            }
        }
    }
    
    @MainActor
    private func showOnMainThread() {
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
            
            windowController = NSWindowController(window: window)
        }
        
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }
}
