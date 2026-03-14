import AppKit
import SwiftUI
import Combine

@objc public class OakNotificationManager: NSObject, @unchecked Sendable {
    @objc public static let shared = OakNotificationManager()
    
    private let model = ToastViewModel()
    // Accessed only on Main Thread
    private var windowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {}
    
    @objc public func show(message: String, type: Int) {
        let toastType: ToastType
        switch type {
        case 1: toastType = .error
        case 2: toastType = .warning
        case 3: toastType = .info
        case 4: toastType = .info
        default: toastType = .info
        }
        
        Task { @MainActor in
            self.performShow(message: message, type: toastType)
        }
    }
    
    @MainActor
    private func performShow(message: String, type: ToastType) {
        self.ensureWindow()
        self.model.show(message: message, type: type)
    }
    
    @MainActor
    private func ensureWindow() {
        if windowController == nil {
            let view = NotificationView(model: model)
            let hostingController = NSHostingController(rootView: view)
            hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
            
            // Create a transparent, borderless window
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
                                  styleMask: [.borderless],
                                  backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.ignoresMouseEvents = true 
            window.hasShadow = false
            
            // Center horizontally at top of screen
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.midX - 200
                let y = screenRect.maxY - 150
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            window.contentViewController = hostingController
            windowController = NSWindowController(window: window)
            windowController?.showWindow(nil)
            
            // Update mouse interaction based on toast presence
            model.$currentToast
                .receive(on: DispatchQueue.main)
                .sink { [weak window] toast in
                    window?.ignoresMouseEvents = (toast == nil)
                }
                .store(in: &cancellables)
        }
    }
}
