import SwiftUI

struct CompletionRowView: View {
    let item: OakCompletionItem
    let isSelected: Bool
    @EnvironmentObject var theme: OakThemeEnvironment

    var body: some View {
        HStack(spacing: 6) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }

            Text(item.label)
                .font(.system(size: theme.fontSize, design: .monospaced))
                .foregroundStyle(isSelected ? Color(nsColor: .alternateSelectedControlTextColor) : .primary)
                .lineLimit(1)

            Spacer()

            if !item.detail.isEmpty {
                Text(item.detail)
                    .font(.system(size: max(theme.fontSize - 2, 9)))
                    .foregroundStyle(isSelected ? Color(nsColor: .alternateSelectedControlTextColor).opacity(0.7) : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
    }
}
