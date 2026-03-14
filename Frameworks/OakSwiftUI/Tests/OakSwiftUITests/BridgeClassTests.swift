import Testing
import AppKit
@testable import OakSwiftUI

// MARK: - OakTooltipContent

@Test func tooltipContentInitWithBody() {
    let body = NSAttributedString(string: "Hello world")
    let content = OakTooltipContent(body: body)
    #expect(content.body.string == "Hello world")
    #expect(content.title == nil)
    #expect(content.codeSnippet == nil)
    #expect(content.language == nil)
}

@Test func tooltipContentConvenienceInit() {
    let body = NSAttributedString(string: "Description")
    let content = OakTooltipContent(
        title: "MyFunc",
        body: body,
        codeSnippet: "func myFunc() -> Int",
        language: "swift"
    )
    #expect(content.title == "MyFunc")
    #expect(content.body.string == "Description")
    #expect(content.codeSnippet == "func myFunc() -> Int")
    #expect(content.language == "swift")
}

@Test func tooltipContentPropertiesAreMutable() {
    let content = OakTooltipContent(body: NSAttributedString(string: "initial"))
    content.title = "Updated"
    content.codeSnippet = "let x = 1"
    content.language = "swift"
    #expect(content.title == "Updated")
    #expect(content.codeSnippet == "let x = 1")
    #expect(content.language == "swift")
}

// MARK: - OakCompletionPopup

@Test @MainActor func completionPopupInitWithTheme() {
    let theme = OakThemeEnvironment()
    let popup = OakCompletionPopup(theme: theme)
    #expect(popup.isVisible == false)
    #expect(popup.delegate == nil)
}

@Test @MainActor func completionPopupDismissWhenNotShown() {
    let theme = OakThemeEnvironment()
    let popup = OakCompletionPopup(theme: theme)
    // Dismissing when no window is open should not crash
    popup.dismiss()
    #expect(popup.isVisible == false)
}

@Test @MainActor func completionPopupUpdateFilterWhenNotShown() {
    let theme = OakThemeEnvironment()
    let popup = OakCompletionPopup(theme: theme)
    // Filtering with no viewModel should not crash
    popup.updateFilter("test")
    #expect(popup.isVisible == false)
}

// MARK: - OakInfoTooltip

@Test @MainActor func infoTooltipInitWithTheme() {
    let theme = OakThemeEnvironment()
    let tooltip = OakInfoTooltip(theme: theme)
    #expect(tooltip.isVisible == false)
    #expect(tooltip.delegate == nil)
}

@Test @MainActor func infoTooltipDismissWhenNotShown() {
    let theme = OakThemeEnvironment()
    let tooltip = OakInfoTooltip(theme: theme)
    // Dismissing when no popover exists should not crash
    tooltip.dismiss()
    #expect(tooltip.isVisible == false)
}

@Test @MainActor func infoTooltipRepositionWhenNotShown() {
    let theme = OakThemeEnvironment()
    let tooltip = OakInfoTooltip(theme: theme)
    // Repositioning with no popover should not crash
    tooltip.reposition(to: NSRect(x: 0, y: 0, width: 100, height: 20))
    #expect(tooltip.isVisible == false)
}

// MARK: - OakFloatingPanel

@Test @MainActor func floatingPanelDefaultState() {
    let panel = OakFloatingPanel()
    #expect(panel.isVisible == false)
    #expect(panel.delegate == nil)
}

@Test @MainActor func floatingPanelCloseWhenNotShown() {
    let panel = OakFloatingPanel()
    // Closing when no panel exists should not crash
    panel.close()
    #expect(panel.isVisible == false)
}
