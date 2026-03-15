import SwiftUI

struct DocDetailView: View {
	let documentation: NSAttributedString
	@EnvironmentObject var theme: OakThemeEnvironment

	var body: some View {
		ScrollView {
			Text(AttributedString(documentation))
				.font(.system(size: max(theme.fontSize - 1, 10)))
				.lineLimit(nil)
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(10)
		}
		.frame(width: 260)
	}
}
