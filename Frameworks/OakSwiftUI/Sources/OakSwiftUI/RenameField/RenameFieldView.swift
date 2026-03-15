import SwiftUI

struct RenameFieldView: View {
    @ObservedObject var theme: OakThemeEnvironment
    @State var text: String
    var onConfirm: (String) -> Void
    var onDismiss: () -> Void

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: theme.fontSize, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: 200)
            .onSubmit {
                let trimmed = text.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    onConfirm(trimmed)
                }
            }
            .onExitCommand {
                onDismiss()
            }
    }
}
