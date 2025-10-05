import SwiftUI
import UniformTypeIdentifiers
#if canImport(Core)
import Core
#endif
#if canImport(PointsEngine)
import PointsEngine
#endif

struct ExportView: View {
    let childId: ChildID
    let ledger: PointsLedger

    @State private var exportFormat: ExportFormat = .csv
    @State private var showShareSheet = false
    @State private var exportData: Data?
    @State private var exportFilename: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Data")
                .font(.title2)
                .fontWeight(.semibold)

            Picker("Format", selection: $exportFormat) {
                Text("CSV").tag(ExportFormat.csv)
                Text("JSON").tag(ExportFormat.json)
            }
            .pickerStyle(.segmented)

            Button("Export") {
                performExport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(exportData != nil)

            if exportData != nil {
                Text("Export ready to share")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .sheet(isPresented: $showShareSheet) {
            if let data = exportData {
                ShareSheet(items: [data], filename: exportFilename)
            }
        }
    }

    private func performExport() {
        let exporter = DataExporter()

        switch exportFormat {
        case .csv:
            let entries = ledger.getEntries(childId: childId)
            let csvString = exporter.exportToCSV(entries: entries, childId: childId)
            exportData = csvString.data(using: String.Encoding.utf8)
            exportFilename = "points_export_\(childId.rawValue).csv"

        case .json:
            let exportData = exporter.createExportData(childIds: [childId], ledger: ledger)
            do {
                let jsonData = try exporter.exportToJSON(data: exportData)
                self.exportData = jsonData
                self.exportFilename = "points_export_\(childId.rawValue).json"
            } catch {
                print("Export error: \(error)")
                return
            }
        }

        showShareSheet = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create temporary file for sharing
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        if let data = items.first as? Data {
            try? data.write(to: fileURL)
        }

        let controller = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let ledger = PointsLedger()
    let childId = ChildID("preview")
    ledger.recordAccrual(childId: childId, points: 100, timestamp: Date())
    ledger.recordRedemption(childId: childId, points: 50, timestamp: Date())

    return ExportView(childId: childId, ledger: ledger)
}
