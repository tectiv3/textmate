import SwiftUI

struct DocDetailView: View {
	let documentation: NSAttributedString
	var isVerticalLayout: Bool = false
	@EnvironmentObject var theme: OakThemeEnvironment

	var body: some View {
		ScrollView {
			AttributedTextView(attributedString: documentation, fontSize: max(theme.fontSize - 1, 10))
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(10)
		}
		.modifier(DocPanelFrameModifier(isVerticalLayout: isVerticalLayout))
	}
}

private struct AttributedTextView: NSViewRepresentable {
	let attributedString: NSAttributedString
	let fontSize: CGFloat

	func makeNSView(context: Context) -> NSTextField {
		let field = NSTextField(frame: .zero)
		field.isEditable = false
		field.isSelectable = true
		field.isBordered = false
		field.drawsBackground = false
		field.lineBreakMode = .byWordWrapping
		field.preferredMaxLayoutWidth = 240
		field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		return field
	}

	func updateNSView(_ field: NSTextField, context: Context) {
		field.attributedStringValue = attributedString
	}
}

private struct DocPanelFrameModifier: ViewModifier {
	let isVerticalLayout: Bool

	func body(content: Content) -> some View {
		if isVerticalLayout {
			content
				.frame(maxWidth: .infinity)
				.frame(maxHeight: 200)
		} else {
			content
				.frame(width: 260)
		}
	}
}
