import SwiftUI

/// Reusable card container for dashboard components
struct DashboardCard<Content: View>: View {
    let title: String
    let systemImage: String?
    let content: Content

    init(
        title: String,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if let systemImage = systemImage {
                    Label(title, systemImage: systemImage)
                        .font(.headline)
                        .foregroundStyle(.primary)
                } else {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Spacer()
            }

            // Content
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    DashboardCard(title: "Test Card", systemImage: "star.fill") {
        Text("Card content goes here")
    }
    .padding()
}
