import SwiftUI

struct CompletionListView: View {
	@ObservedObject var viewModel: CompletionViewModel
	let showDocPanel: Bool
	@EnvironmentObject var theme: OakThemeEnvironment

	var body: some View {
		HStack(spacing: 0) {
			itemsList
			if showDocPanel {
				Divider()
				docPanel
			}
		}
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 6))
	}

	private var itemsList: some View {
		ScrollViewReader { proxy in
			ScrollView(.vertical) {
				LazyVStack(spacing: 0) {
					ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
						CompletionRowView(
							item: item,
							isSelected: index == viewModel.selectedIndex
						)
						.id(item.id)
						.accessibilityElement(children: .ignore)
						.accessibilityLabel(item.label)
						.accessibilityHint(item.detail)
						.accessibilityAddTraits(index == viewModel.selectedIndex ? .isSelected : [])
					}
				}
				.padding(.vertical, 4)
				.padding(.horizontal, 4)
			}
			.accessibilityElement(children: .contain)
			.onChange(of: viewModel.selectedIndex) { _, newValue in
				guard newValue < viewModel.filteredItems.count else { return }
				withAnimation(.easeOut(duration: 0.1)) {
					proxy.scrollTo(viewModel.filteredItems[newValue].id, anchor: .center)
				}
			}
		}
	}

	private var docPanel: some View {
		Group {
			if let docs = viewModel.resolvedDocumentation, docs.length > 0 {
				DocDetailView(documentation: docs)
					.transition(.opacity)
			} else {
				Color.clear
					.frame(width: 260)
			}
		}
		.animation(.easeIn(duration: 0.1), value: viewModel.resolvedDocumentation != nil)
	}
}
