import SwiftUI

struct LogView: View {
	@ObservedObject var model: LogViewModel
	@State private var searchText = ""
	@State private var autoScroll = true

	var filteredEntries: [LogEntry] {
		if searchText.isEmpty {
			return model.entries
		} else {
			return model.entries.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			ScrollViewReader { proxy in
				List {
					ForEach(filteredEntries) { entry in
						LogRow(entry: entry)
							.id(entry.id)
							.listRowSeparator(.hidden)
					}
					Color.clear
						.frame(height: 1)
						.id("bottom-anchor")
				}
				.listStyle(PlainListStyle())
				.onChange(of: model.entries.count) { _, _ in
					if autoScroll {
						withAnimation {
							proxy.scrollTo("bottom-anchor", anchor: .bottom)
						}
					}
				}
				.onChange(of: searchText) { _, _ in
					if autoScroll {
						proxy.scrollTo("bottom-anchor", anchor: .bottom)
					}
				}
			}

			HStack(spacing: 12) {
				TextField("Filter…", text: $searchText)
					.textFieldStyle(RoundedBorderTextFieldStyle())

				Toggle("Auto-scroll", isOn: $autoScroll)
					.toggleStyle(.switch)
					.controlSize(.small)

				Button("Clear") {
					model.clear()
				}
				.controlSize(.small)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(Color(NSColor.windowBackgroundColor))
		}
		.frame(minWidth: 400, minHeight: 300)
	}
}

struct LogRow: View {
	let entry: LogEntry

	private static let timeFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "HH:mm:ss.SSS"
		return f
	}()

	private var arrow: String {
		switch entry.source {
		case "request": return "→"
		case "notify":  return "→"
		case "response": return "←"
		case "event":   return "←"
		case "server":  return "◇"
		case "error":   return "✗"
		default:        return "·"
		}
	}

	private var arrowColor: Color {
		switch entry.source {
		case "request":  return .blue
		case "notify":   return .cyan
		case "response": return .green
		case "event":    return .purple
		case "server":   return .secondary
		case "error":    return .red
		default:         return .secondary
		}
	}

	private var messageColor: Color {
		switch entry.source {
		case "error": return .red
		case "server": return .secondary
		default: return .primary
		}
	}

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			Text(arrow)
				.font(.system(size: 12, weight: .bold, design: .monospaced))
				.foregroundColor(arrowColor)
				.frame(width: 14, alignment: .center)

			Text(LogRow.timeFormatter.string(from: entry.date))
				.font(.system(size: 11, design: .monospaced))
				.foregroundColor(.secondary)

			Text(entry.message)
				.font(.system(size: 12, design: .monospaced))
				.foregroundColor(messageColor)
				.textSelection(.enabled)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.vertical, 1)
	}
}
