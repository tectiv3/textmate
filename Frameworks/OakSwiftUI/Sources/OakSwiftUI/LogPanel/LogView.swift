import SwiftUI

struct LogView: View {
    @ObservedObject var model: LogViewModel
    @State private var searchText = ""
    
    var filteredEntries: [LogEntry] {
        if searchText.isEmpty {
            return model.entries
        } else {
            return model.entries.reversed().filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List(filteredEntries) { entry in
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
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }
            .listStyle(PlainListStyle())
            
            HStack {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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
