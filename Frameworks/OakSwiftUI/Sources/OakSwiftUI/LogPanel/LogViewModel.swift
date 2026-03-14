import SwiftUI
import Combine

public struct LogEntry: Identifiable, Equatable {
    public let id = UUID()
    public let date = Date()
    public let message: String
    public let level: Int // 0: debug, 1: info, 2: warning, 3: error
    public let source: String
}

@MainActor
public class LogViewModel: ObservableObject {
    @Published public var entries: [LogEntry] = []
    private let maxEntries = 1000

    nonisolated init() {}

    public func add(message: String, level: Int, source: String = "LSP") {
        let entry = LogEntry(message: message, level: level, source: source)
        self.entries.append(entry)
        if self.entries.count > self.maxEntries {
            self.entries.removeFirst(self.entries.count - self.maxEntries)
        }
    }

    public func clear() {
        self.entries.removeAll()
    }
}
