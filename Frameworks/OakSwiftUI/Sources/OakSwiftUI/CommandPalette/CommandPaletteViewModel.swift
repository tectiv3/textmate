import AppKit
import Combine

public enum PaletteMode: String, CaseIterable, Sendable {
	case recentProjects
	case commands
	case symbols
	case bundleEditor
	case goToLine
	case findInProject
	case settings

	public var prefix: Character? {
		switch self {
		case .recentProjects: return nil
		case .commands:       return ">"
		case .symbols:        return "@"
		case .bundleEditor:   return "#"
		case .goToLine:       return ":"
		case .findInProject:  return "/"
		case .settings:       return "~"
		}
	}

	public var label: String {
		switch self {
		case .recentProjects: return "Recent Projects"
		case .commands:       return "Commands"
		case .symbols:        return "Symbols"
		case .bundleEditor:   return "Bundles"
		case .goToLine:       return "Go to Line"
		case .findInProject:  return "Find"
		case .settings:       return "Settings"
		}
	}

	public var placeholder: String {
		switch self {
		case .recentProjects: return "Search recent projects..."
		case .commands:       return "Search commands..."
		case .symbols:        return "Search symbols..."
		case .bundleEditor:   return "Search bundles..."
		case .goToLine:       return "Type a line number..."
		case .findInProject:  return "Search in project..."
		case .settings:       return "Search settings..."
		}
	}

	public var intValue: Int {
		switch self {
		case .recentProjects: return 0
		case .commands:       return 1
		case .symbols:        return 2
		case .bundleEditor:   return 3
		case .goToLine:       return 4
		case .findInProject:  return 5
		case .settings:       return 6
		}
	}

	public init?(prefix: Character) {
		guard let mode = PaletteMode.allCases.first(where: { $0.prefix == prefix }) else {
			return nil
		}
		self = mode
	}
}

public struct RankedItem: Identifiable, Sendable {
	public let item: OakCommandPaletteItem
	public let matchedIndices: [Int]
	public let score: Double
	public var id: UUID { item.id }
}

@MainActor
public class CommandPaletteViewModel: ObservableObject {
	@Published public var filterText: String = "" {
		didSet { processFilterChange() }
	}
	@Published public private(set) var activeMode: PaletteMode = .recentProjects
	@Published public private(set) var filteredItems: [RankedItem] = []
	@Published public var selectedIndex: Int = 0

	public var onItemSelected: ((OakCommandPaletteItem) -> Void)?
	public var onDismiss: (() -> Void)?
	// Called when mode switches and items for that mode haven't been loaded yet
	public var onModeSwitch: ((PaletteMode) -> [OakCommandPaletteItem])?

	private var itemsByMode: [PaletteMode: [OakCommandPaletteItem]] = [:]

	public init() {}

	public var queryText: String {
		guard let prefix = activeMode.prefix, filterText.first == prefix else {
			return filterText
		}
		return String(filterText.dropFirst())
	}

	public func setItems(_ items: [OakCommandPaletteItem], forMode mode: PaletteMode) {
		itemsByMode[mode] = items
		if mode == activeMode {
			applyFilter()
		}
	}

	public func selectNext() {
		if selectedIndex < filteredItems.count - 1 {
			selectedIndex += 1
		}
	}

	public func selectPrevious() {
		if selectedIndex > 0 {
			selectedIndex -= 1
		}
	}

	public func acceptSelection() {
		guard selectedIndex >= 0, selectedIndex < filteredItems.count else { return }
		onItemSelected?(filteredItems[selectedIndex].item)
	}

	public func requestDismiss() {
		onDismiss?()
	}

	public var selectedItem: OakCommandPaletteItem? {
		guard selectedIndex >= 0, selectedIndex < filteredItems.count else { return nil }
		return filteredItems[selectedIndex].item
	}

	private func processFilterChange() {
		let newMode: PaletteMode
		if let first = filterText.first, let mode = PaletteMode(prefix: first) {
			newMode = mode
		} else {
			newMode = .recentProjects
		}

		if newMode != activeMode {
			activeMode = newMode
			if itemsByMode[newMode] == nil, let items = onModeSwitch?(newMode) {
				itemsByMode[newMode] = items
			}
		}

		applyFilter()
		selectedIndex = 0
	}

	private func applyFilter() {
		let query = queryText
		guard let items = itemsByMode[activeMode] else {
			if activeMode == .goToLine {
				filteredItems = goToLineItems(query: query)
				return
			}
			if activeMode == .findInProject {
				filteredItems = findInProjectItems(query: query)
				return
			}
			filteredItems = []
			return
		}

		if query.isEmpty {
			filteredItems = items.map { RankedItem(item: $0, matchedIndices: [], score: 0) }
			return
		}

		filteredItems = items
			.compactMap { item -> RankedItem? in
				guard let result = FuzzyMatcher.score(item.title, query: query) else { return nil }
				return RankedItem(item: item, matchedIndices: result.matchedIndices, score: Double(result.score))
			}
			.sorted { $0.score > $1.score }
	}

	private func goToLineItems(query: String) -> [RankedItem] {
		let lineStr = query.isEmpty ? "..." : query
		let title = "Go to line \(lineStr)"
		let item = OakCommandPaletteItem(
			title: title, subtitle: "", keyEquivalent: "",
			category: .goToLine, actionIdentifier: "line:\(query)")
		return [RankedItem(item: item, matchedIndices: [], score: 0)]
	}

	private func findInProjectItems(query: String) -> [RankedItem] {
		let searchTerm = query.isEmpty ? "..." : "\"\(query)\""
		let title = "Find \(searchTerm) in Project"
		let item = OakCommandPaletteItem(
			title: title, subtitle: "", keyEquivalent: "\u{21E7}\u{2318}F",
			category: .findInProject, actionIdentifier: "find:\(query)")
		return [RankedItem(item: item, matchedIndices: [], score: 0)]
	}
}
