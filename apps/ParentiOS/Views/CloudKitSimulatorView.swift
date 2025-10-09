import SwiftUI
#if canImport(Core)
import Core
#endif
// SyncKit files are compiled directly into the target, no import needed

struct CloudKitSimulatorView: View {
    @StateObject private var debugger = CloudKitDebugger.shared
    @EnvironmentObject var childrenManager: ChildrenManager
    @EnvironmentObject var syncService: SyncService

    @State private var childName = ""
    @State private var isAddingChild = false
    @State private var simulatedError: String = ""
    @State private var isSyncing = false
    @State private var lastSyncResult: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Controls section
                    SectionHeaderView("Controls")
                    
                    HStack {
                        Button(action: {
                            if debugger.isMonitoring {
                                debugger.stopMonitoring()
                            } else {
                                debugger.startMonitoring()
                            }
                        }) {
                            Text(debugger.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: {
                            debugger.clearLogs()
                        }) {
                            Text("Clear Logs")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Child Management Simulation
                    SectionHeaderView("Child Management Simulation")
                    
                    // Add Child Simulation
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add Child")
                            .font(.headline)
                        
                        HStack {
                            TextField("Child Name", text: $childName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Add") {
                                addChild()
                            }
                            .disabled(childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAddingChild)
                            .opacity(isAddingChild ? 0.5 : 1.0)
                        }
                    }
                    
                    // Sync Operations
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sync Operations")
                            .font(.headline)

                        Button("Refresh Children from Cloud") {
                            refreshChildren()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                        .disabled(isSyncing)

                        Button("Test Full CloudKit Sync") {
                            testFullSync()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .disabled(isSyncing)

                        if isSyncing {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Syncing...")
                                    .font(.caption)
                            }
                        }

                        if !lastSyncResult.isEmpty {
                            Text(lastSyncResult)
                                .font(.caption)
                                .foregroundColor(lastSyncResult.contains("Error") ? .red : .green)
                                .padding(.top, 4)
                        }
                    }
                    
                    // Error Simulation
                    SectionHeaderView("Error Simulation")
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Simulate Errors")
                            .font(.headline)
                        
                        TextField("Error Message", text: $simulatedError)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Trigger Error") {
                            triggerError()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                    }
                    
                    // Statistics
                    SectionHeaderView("Statistics")
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Total Logs:")
                            Spacer()
                            Text("\(debugger.debugLogs.count)")
                        }
                        
                        HStack {
                            Text("Active Children:")
                            Spacer()
                            Text("\(childrenManager.children.count)")
                        }
                        
                        HStack {
                            Text("Monitoring:")
                            Spacer()
                            Text(debugger.isMonitoring ? "ON" : "OFF")
                                .foregroundColor(debugger.isMonitoring ? .green : .red)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    
                    // Recent Logs
                    SectionHeaderView("Recent Logs")
                    
                    if debugger.debugLogs.isEmpty {
                        Text("No logs yet. Start monitoring to see CloudKit operations.")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(debugger.debugLogs.suffix(20).reversed()) { log in
                            LogEntryRow(entry: log)
                                .padding(.vertical, 4)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("CloudKit Simulator")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func addChild() {
        guard !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isAddingChild = true
        Task {
            let result = await childrenManager.addChild(named: childName)
            DispatchQueue.main.async {
                isAddingChild = false
                switch result {
                case .success(let child):
                    debugger.logOperation("Simulated Child Added", details: "Name: \(child.name), ID: \(child.id.rawValue)")
                    childName = ""
                case .failure(let error):
                    debugger.logOperation("Simulated Add Child Failed", details: "Name: \(childName)", error: error)
                }
            }
        }
    }
    
    private func refreshChildren() {
        debugger.logOperation("Manual Refresh Triggered", category: .child, details: "User initiated refresh", error: nil)
        Task {
            await childrenManager.refreshChildrenFromCloud(familyId: FamilyID("default-family"))
        }
    }

    private func testFullSync() {
        isSyncing = true
        lastSyncResult = ""
        debugger.logOperation("Full Sync Test Started", category: .sync, details: "Testing all CloudKit operations", error: nil)

        Task {
            do {
                let familyId = FamilyID("default-family")

                // 1. Test family fetch/save
                debugger.logOperation("Testing Family Operations", category: .sync, details: "Fetching and saving family", error: nil)
                let family = try await syncService.fetchFamily(id: familyId)
                try await syncService.saveFamily(family)

                // 2. Test children fetch
                debugger.logOperation("Testing Child Operations", category: .sync, details: "Fetching children", error: nil)
                let children = try await syncService.fetchChildren(familyId: familyId)
                debugger.logOperation("Children Fetched", category: .sync, details: "Count: \(children.count)", error: nil)

                // 3. Test pairing codes fetch
                debugger.logOperation("Testing Pairing Code Operations", category: .sync, details: "Fetching pairing codes", error: nil)
                let codes = try await syncService.fetchPairingCodes(familyId: familyId)
                debugger.logOperation("Pairing Codes Fetched", category: .sync, details: "Count: \(codes.count)", error: nil)

                // 4. Test app rules fetch
                debugger.logOperation("Testing App Rule Operations", category: .sync, details: "Fetching app rules", error: nil)
                let rules = try await syncService.fetchAppRules(familyId: familyId, childId: nil)
                debugger.logOperation("App Rules Fetched", category: .sync, details: "Count: \(rules.count)", error: nil)

                // 5. Test sync changes
                debugger.logOperation("Testing Sync Changes", category: .sync, details: "Running sync changes", error: nil)
                let (changes, token) = try await syncService.syncChanges(since: nil)
                debugger.logOperation("Sync Changes Completed", category: .sync, details: "Changes: \(changes.count), Token: \(token?.description ?? "none")", error: nil)

                await MainActor.run {
                    lastSyncResult = "✓ Sync completed successfully: \(children.count) children, \(codes.count) codes, \(rules.count) rules"
                    isSyncing = false
                }
            } catch {
                debugger.logOperation("Full Sync Test Failed", category: .sync, details: nil, error: error)
                await MainActor.run {
                    lastSyncResult = "✗ Error: \(error.localizedDescription)"
                    isSyncing = false
                }
            }
        }
    }

    private func triggerError() {
        if !simulatedError.isEmpty {
            debugger.logOperation("Simulated Error", category: .general, details: "Manual error trigger", error: NSError(domain: "CloudKitSimulator", code: 999, userInfo: [NSLocalizedDescriptionKey: simulatedError]))
        }
    }
}

struct SectionHeaderView: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.top)
    }
}

struct CloudKitSimulatorView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitSimulatorView()
    }
}