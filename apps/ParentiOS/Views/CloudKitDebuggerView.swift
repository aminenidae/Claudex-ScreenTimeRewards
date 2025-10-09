import SwiftUI
#if canImport(Core)
import Core
#endif

struct CloudKitDebuggerView: View {
    @StateObject private var debugger = CloudKitDebugger.shared
    @State private var selectedCategory: CloudKitOperationCategory? = nil
    @State private var showErrorsOnly = false

    var filteredLogs: [DebugLogEntry] {
        debugger.debugLogs
            .filter { log in
                // Filter by category
                if let selectedCategory = selectedCategory {
                    guard log.category == selectedCategory else { return false }
                }
                // Filter by errors
                if showErrorsOnly {
                    guard log.hasError else { return false }
                }
                return true
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var categoryCounts: [CloudKitOperationCategory: Int] {
        Dictionary(grouping: debugger.debugLogs, by: { $0.category })
            .mapValues { $0.count }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("CloudKit Debugger")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button(action: {
                        debugger.clearLogs()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(debugger.debugLogs.isEmpty)
                }
                .padding()

                // Monitoring toggle and stats
                HStack {
                    Toggle("Monitoring", isOn: Binding(
                        get: { debugger.isMonitoring },
                        set: { isMonitoring in
                            if isMonitoring {
                                debugger.startMonitoring()
                            } else {
                                debugger.stopMonitoring()
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle())

                    Spacer()

                    Text("Logs: \(filteredLogs.count)/\(debugger.debugLogs.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Filter controls
                VStack(spacing: 8) {
                    // Category filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterPill(
                                title: "All",
                                count: debugger.debugLogs.count,
                                isSelected: selectedCategory == nil,
                                color: .gray
                            ) {
                                selectedCategory = nil
                            }

                            ForEach([
                                CloudKitOperationCategory.family,
                                .child,
                                .appRule,
                                .pairingCode,
                                .sync,
                                .monitoring,
                                .general
                            ], id: \.self) { category in
                                if let count = categoryCounts[category], count > 0 {
                                    FilterPill(
                                        title: category.rawValue,
                                        count: count,
                                        isSelected: selectedCategory == category,
                                        color: colorForCategory(category)
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Errors only toggle
                    Toggle("Errors Only", isOn: $showErrorsOnly)
                        .toggleStyle(SwitchToggleStyle())
                        .padding(.horizontal)
                }
                .padding(.bottom, 8)

                Divider()

                // Logs list
                if filteredLogs.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(debugger.debugLogs.isEmpty ? "No logs yet" : "No matching logs")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if debugger.isMonitoring {
                            Text("CloudKit operations will appear here")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Enable monitoring to see CloudKit operations")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                } else {
                    List(filteredLogs) { log in
                        LogEntryRow(entry: log)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func colorForCategory(_ category: CloudKitOperationCategory) -> Color {
        switch category {
        case .family: return .blue
        case .child: return .green
        case .appRule: return .orange
        case .pairingCode: return .purple
        case .sync: return .indigo
        case .monitoring: return .gray
        case .general: return .primary
        }
    }
}

struct FilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("(\(count))")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? color : .secondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

struct LogEntryRow: View {
    let entry: DebugLogEntry

    private var categoryColor: Color {
        switch entry.category {
        case .family: return .blue
        case .child: return .green
        case .appRule: return .orange
        case .pairingCode: return .purple
        case .sync: return .indigo
        case .monitoring: return .gray
        case .general: return .primary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Category badge
                Text(entry.category.rawValue)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.2))
                    .foregroundColor(categoryColor)
                    .cornerRadius(4)

                Text(entry.operation)
                    .font(.headline)
                    .foregroundColor(entry.hasError ? .red : .primary)

                Spacer()

                Text(entry.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let details = entry.details {
                Text(details)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = entry.error {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CloudKitDebuggerView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitDebuggerView()
    }
}