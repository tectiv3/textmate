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
						VStack(alignment: .leading, spacing: 2) {
							HStack {
								Text(entry.source)
									.font(.caption)
									.fontWeight(.bold)
									.foregroundColor(.secondary)
								Text(entry.date, style: .time)
									.font(.caption)
									.foregroundColor(.secondary)
								Spacer()
							}
							Text(entry.message)
								.font(.system(.body, design: .monospaced))
								.fixedSize(horizontal: false, vertical: true)
								.textSelection(.enabled)
						}
						.padding(.vertical, 4)
						.id(entry.id)
					}
					// Invisible anchor at the very end so scrollTo lands below the last real row
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

			HStack {
				TextField("Search...", text: $searchText)
					.textFieldStyle(RoundedBorderTextFieldStyle())

				Toggle("Auto", isOn: $autoScroll)
					.toggleStyle(.switch)
					.help("Auto-scroll to bottom")

				Button("Clear") {
					model.clear()
				}
			}
			.padding()
			.background(Color(NSColor.windowBackgroundColor))
		}
		.frame(minWidth: 400, minHeight: 300)
	}
}
