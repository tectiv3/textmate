import SwiftUI

struct CompletionListView: View {
	@ObservedObject var viewModel: CompletionViewModel
	@EnvironmentObject var theme: OakThemeEnvironment

	var body: some View {
		HStack(spacing: 0) {
			itemsList
			if let docs = viewModel.resolvedDocumentation, !docs.isEmpty {
				Divider()
				DocDetailView(documentation: docs)
					.transition(.move(edge: .trailing).combined(with: .opacity))
			}
		}
		.animation(.easeInOut(duration: 0.15), value: viewModel.resolvedDocumentation != nil)
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
			}
			.accessibilityElement(children: .contain)
			.onChange(of: viewModel.selectedIndex) { _, newValue in
				guard newValue < viewModel.filteredItems.count else { return }
				withAnimation(.easeOut(duration: 0.1)) {
					proxy.scrollTo(viewModel.filteredItems[newValue].id, anchor: .center)
				}
			}
		}
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 6))
	}
}
