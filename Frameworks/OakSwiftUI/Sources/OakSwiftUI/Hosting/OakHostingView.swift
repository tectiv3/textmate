import AppKit
import SwiftUI

/// Thin wrapper around NSHostingView that integrates with AppKit responder chain
/// and injects ThemeEnvironment into the SwiftUI view hierarchy.
public class OakHostingView<Content: View>: NSHostingView<AnyView> {
    private let themeEnvironment: OakThemeEnvironment

    public init(rootView: Content, theme: OakThemeEnvironment) {
        self.themeEnvironment = theme
        let themed = AnyView(
            rootView.environmentObject(theme)
        )
        super.init(rootView: themed)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    @MainActor required init(rootView: AnyView) {
        fatalError("Use init(rootView:theme:) instead")
    }

    public override var intrinsicContentSize: NSSize {
        super.intrinsicContentSize
    }
}
