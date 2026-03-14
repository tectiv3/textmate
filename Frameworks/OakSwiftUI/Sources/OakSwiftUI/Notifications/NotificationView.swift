import SwiftUI

struct NotificationView: View {
    @ObservedObject var model: ToastViewModel
    
    var body: some View {
        VStack {
            if let toast = model.currentToast {
                HStack(spacing: 12) {
                    Image(systemName: iconName(for: toast.type))
                        .foregroundColor(color(for: toast.type))
                    Text(toast.message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.85))
                .cornerRadius(12)
                .shadow(radius: 6)
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)))
                .animation(.spring(), value: toast)
                .onTapGesture {
                    model.currentToast = nil
                }
            }
            Spacer()
        }
        .padding(.top, 20)
    }
    
    func iconName(for type: ToastType) -> String {
        switch type {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
    
    func color(for type: ToastType) -> Color {
        switch type {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}
