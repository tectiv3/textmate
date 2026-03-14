import AppKit
import Combine

@MainActor
public class CompletionViewModel: ObservableObject {
    @Published public private(set) var filteredItems: [OakCompletionItem] = []
    @Published public var selectedIndex: Int = 0

    private var allItems: [OakCompletionItem] = []
    private var currentFilter: String = ""

    public init() {}

    public func setItems(_ items: [OakCompletionItem]) {
        allItems = items
        applyFilter()
    }

    public func updateFilter(_ text: String) {
        currentFilter = text
        applyFilter()
        selectedIndex = 0
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

    public var selectedItem: OakCompletionItem? {
        guard selectedIndex >= 0, selectedIndex < filteredItems.count else { return nil }
        return filteredItems[selectedIndex]
    }

    private func applyFilter() {
        filteredItems = FuzzyMatcher.filter(allItems, query: currentFilter, keyPath: \.label)
    }
}
