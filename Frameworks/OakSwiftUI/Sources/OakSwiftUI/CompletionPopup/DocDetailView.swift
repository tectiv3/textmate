import SwiftUI

struct DocDetailView: View {
	let documentation: String
	@EnvironmentObject var theme: OakThemeEnvironment

	var body: some View {
		ScrollView {
			Text(attributedDocumentation)
				.font(.system(size: max(theme.fontSize - 1, 10)))
				.lineLimit(nil)
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(10)
		}
		.frame(width: 260)
	}

	private var attributedDocumentation: AttributedString {
		var result = AttributedString()
		let lines = documentation.components(separatedBy: "\n")
		var inCodeBlock = false

		for (index, line) in lines.enumerated() {
			if index > 0 {
				result.append(AttributedString("\n"))
			}

			if line.hasPrefix("```") {
				inCodeBlock.toggle()
				continue
			}

			if inCodeBlock {
				var codeLine = AttributedString(line)
				codeLine.font = .system(size: theme.fontSize, design: .monospaced)
				codeLine.foregroundColor = .primary
				result.append(codeLine)
			} else {
				result.append(parseInlineMarkdown(line))
			}
		}
		return result
	}

	private func parseInlineMarkdown(_ text: String) -> AttributedString {
		var result = AttributedString()
		var i = text.startIndex

		while i < text.endIndex {
			if text[i] == "`" {
				let codeStart = text.index(after: i)
				if codeStart < text.endIndex, let codeEnd = text[codeStart...].firstIndex(of: "`") {
					var code = AttributedString(String(text[codeStart..<codeEnd]))
					code.font = .system(size: max(theme.fontSize - 1, 10), design: .monospaced)
					code.foregroundColor = .primary
					result.append(code)
					i = text.index(after: codeEnd)
					continue
				}
			}

			if text[i] == "*" {
				let next = text.index(after: i)
				if next < text.endIndex && text[next] == "*" {
					let boldStart = text.index(after: next)
					if boldStart < text.endIndex, let range = text[boldStart...].range(of: "**") {
						var bold = AttributedString(String(text[boldStart..<range.lowerBound]))
						bold.font = .system(size: max(theme.fontSize - 1, 10), weight: .bold)
						result.append(bold)
						i = range.upperBound
						continue
					}
				}
			}

			var plain = AttributedString(String(text[i]))
			plain.foregroundColor = .secondary
			result.append(plain)
			i = text.index(after: i)
		}
		return result
	}
}
