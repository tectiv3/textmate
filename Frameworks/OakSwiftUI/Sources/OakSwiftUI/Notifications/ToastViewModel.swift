import SwiftUI
import Combine

public enum ToastType {
	case info
	case warning
	case error
	case success
}

public struct Toast: Identifiable, Equatable {
	public let id = UUID()
	public let message: String
	public let type: ToastType
	public let duration: TimeInterval
}

@MainActor
public class ToastViewModel: ObservableObject {
	@Published public var currentToast: Toast?
	private var dismissTask: Task<Void, Never>?

	nonisolated init() {}

	public func show(message: String, type: ToastType, duration: TimeInterval = 3.0) {
		self.currentToast = Toast(message: message, type: type, duration: duration)
		self.dismissTask?.cancel()
		self.dismissTask = Task {
			try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
			if !Task.isCancelled {
				self.currentToast = nil
			}
		}
	}
}
