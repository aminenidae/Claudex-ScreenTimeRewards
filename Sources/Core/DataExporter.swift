import Foundation
#if canImport(Core)
import Core
#endif

public enum ExportFormat {
    case csv
    case json
}

public struct ExportData: Codable {
    public let exportDate: Date
    public let children: [ChildExportData]

    public init(exportDate: Date, children: [ChildExportData]) {
        self.exportDate = exportDate
        self.children = children
    }
}

public struct ChildExportData: Codable {
    public let childId: String
    public let balance: Int
    public let entries: [PointsLedgerEntry]

    public init(childId: String, balance: Int, entries: [PointsLedgerEntry]) {
        self.childId = childId
        self.balance = balance
        self.entries = entries
    }
}

public final class DataExporter {
    public init() {}

    // MARK: - CSV Export

    public func exportToCSV(entries: [PointsLedgerEntry], childId: ChildID) -> String {
        var csv = "Date,Child,Type,Amount,Description\n"

        for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            let date = formatDate(entry.timestamp)
            let type = entry.type.rawValue.capitalized
            let amount = entry.amount
            let description = descriptionForEntry(entry)

            csv += "\(date),\(childId.rawValue),\(type),\(amount),\"\(description)\"\n"
        }

        return csv
    }

    // MARK: - JSON Export

    public func exportToJSON(data: ExportData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(data)
    }

    // MARK: - Full Export

    public func createExportData(
        childIds: [ChildID],
        ledger: PointsLedgerProtocol
    ) -> ExportData {
        let children = childIds.map { childId in
            ChildExportData(
                childId: childId.rawValue,
                balance: ledger.getBalance(childId: childId),
                entries: ledger.getEntries(childId: childId)
            )
        }

        return ExportData(
            exportDate: Date(),
            children: children
        )
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func descriptionForEntry(_ entry: PointsLedgerEntry) -> String {
        switch entry.type {
        case .accrual:
            return "Learning session"
        case .redemption:
            let minutes = abs(entry.amount) / 10 // Default ratio
            return "Redeemed for \(minutes) minutes"
        case .adjustment:
            return "Manual adjustment"
        }
    }
}
