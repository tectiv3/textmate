import AppKit

@objc public class OakCompletionItem: NSObject, Identifiable {
    public let id = UUID()
    @objc public let label: String
    @objc public let insertText: String?
    @objc public let detail: String
    @objc public let kind: Int
    @objc public var icon: NSImage?

    @objc public var effectiveInsertText: String {
        insertText ?? label
    }

    @objc public init(label: String, insertText: String?, detail: String, kind: Int) {
        self.label = label
        self.insertText = insertText
        self.detail = detail
        self.kind = kind
        super.init()
    }
}
