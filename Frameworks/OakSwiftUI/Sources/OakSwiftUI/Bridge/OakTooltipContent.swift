import AppKit

@objc public class OakTooltipContent: NSObject {
    @objc public var title: String?
    @objc public var body: NSAttributedString
    @objc public var codeSnippet: String?
    @objc public var language: String?

    @objc public init(body: NSAttributedString) {
        self.body = body
        super.init()
    }

    @objc public convenience init(title: String?, body: NSAttributedString, codeSnippet: String?, language: String?) {
        self.init(body: body)
        self.title = title
        self.codeSnippet = codeSnippet
        self.language = language
    }
}
