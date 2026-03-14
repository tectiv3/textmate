import SwiftUI

struct TooltipContentView: View {
    let content: OakTooltipContent
    @EnvironmentObject var theme: OakThemeEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = content.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: theme.fontSize, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if content.body.length > 0 {
                Text(AttributedString(content.body))
                    .font(.system(size: max(theme.fontSize - 1, 10)))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let snippet = content.codeSnippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.system(size: theme.fontSize, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(8)
                    .background(Color(.textBackgroundColor).opacity(0.5))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .frame(maxWidth: 500)
    }
}
