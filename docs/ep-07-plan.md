# EP-07 Implementation Plan: Dashboard & Reporting

**Status:** Ready to implement
**Depends on:** EP-04 (Points Engine) ✅ | EP-05 (Redemption) ✅
**Estimated Effort:** 2-3 days

---

## Overview

Build the parent dashboard UI to display points, learning time, redemptions, and shield status. Add weekly reporting via DeviceActivityReport extension and data export capabilities.

---

## Stories Breakdown

### S-701: Parent Dashboard
**Goal:** Real-time dashboard showing child activity and current state

**UI Components:**
1. **Points Balance Card**
   - Current points balance
   - Today's points earned
   - Progress toward daily cap
   - Visual indicator (progress bar/circle)

2. **Learning Time Card**
   - Today's learning duration
   - This week's learning duration
   - Top learning apps (if available)

3. **Redemptions Card**
   - Recent redemptions list
   - Active exemption countdown (if any)
   - Remaining earned time

4. **Shield Status Card**
   - Current shield state (active/exempted)
   - Number of shielded apps
   - Quick actions (pause/resume shields)

**Data Integration:**
```swift
struct DashboardViewModel: ObservableObject {
    @Published var balance: Int
    @Published var todayPoints: Int
    @Published var todayLearningMinutes: Int
    @Published var weekLearningMinutes: Int
    @Published var recentRedemptions: [PointsLedgerEntry]
    @Published var activeWindow: EarnedTimeWindow?
    @Published var shieldState: ShieldState

    func refresh() async
}
```

**Acceptance:**
- ✅ Dashboard loads in <1s
- ✅ Auto-refresh when returning to foreground
- ✅ Pull-to-refresh gesture
- ✅ Handles empty states gracefully

---

### S-702: Weekly Report Extension (DeviceActivityReport)
**Goal:** Show weekly aggregated learning and reward usage

**Implementation:**
1. Create DeviceActivityReport extension target
2. Implement report view with SwiftUI
3. Query DeviceActivity for weekly totals
4. Match dashboard data within ±5%

**Report Structure:**
```swift
struct WeeklyReportView: View {
    let context: DeviceActivityReport.Context

    var body: some View {
        VStack {
            // Total learning time this week
            // Total reward time this week
            // Daily breakdown chart
            // Top learning apps
        }
    }
}
```

**Data Sources:**
- DeviceActivity API for usage totals
- PointsLedger for points/redemptions
- Cross-validate for accuracy

**Acceptance:**
- ✅ Weekly totals within ±5% of dashboard
- ✅ Chart shows daily breakdown
- ✅ Report renders in extension context

---

### S-703: Data Export
**Goal:** Allow parents to export family activity data

**Export Formats:**
1. **CSV Format**
   ```
   Date,Child,Type,Amount,Description
   2025-10-04,Child1,Accrual,50,Learning session
   2025-10-04,Child1,Redemption,-30,Reward time
   ```

2. **JSON Format**
   ```json
   {
     "exportDate": "2025-10-04T20:00:00Z",
     "children": [{
       "childId": "...",
       "entries": [...],
       "balance": 100
     }]
   }
   ```

**Implementation:**
```swift
struct DataExporter {
    func exportToCSV(ledger: PointsLedger, childId: ChildID) -> String
    func exportToJSON(ledger: PointsLedger, childId: ChildID) -> Data
    func shareExport(data: Data, format: ExportFormat)
}
```

**Acceptance:**
- ✅ Export sanitized (no PII beyond what parent entered)
- ✅ No raw event timelines (aggregates only)
- ✅ Share sheet integration
- ✅ Both CSV and JSON supported

---

### S-704: iPad Layout Optimization
**Goal:** Responsive dashboard that works on iPad

**Adaptive Layout:**
- Use `@Environment(\.horizontalSizeClass)` for layout decisions
- Compact: Vertical stack (iPhone, split-view iPad)
- Regular: Horizontal grid (full-screen iPad)

**Layout Variants:**
```swift
struct DashboardView: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        if sizeClass == .compact {
            VStack { /* Cards stacked */ }
        } else {
            LazyVGrid(columns: [/* 2-3 columns */]) { /* Cards grid */ }
        }
    }
}
```

**Acceptance:**
- ✅ No clipping in split-view
- ✅ Optimal use of space on iPad
- ✅ Smooth transitions between orientations
- ✅ Dynamic Type support

---

## Architecture

### View Hierarchy
```
ParentDashboardView
├── DashboardViewModel (data layer)
├── PointsBalanceCard
├── LearningTimeCard
├── RedemptionsCard
└── ShieldStatusCard
```

### Data Flow
```
PointsEngine/Ledger/ExemptionManager
    ↓
DashboardViewModel (aggregates data)
    ↓
SwiftUI Views (present data)
```

---

## File Structure

**New Files to Create:**
1. `apps/ParentiOS/Views/DashboardView.swift` (~200 LOC)
2. `apps/ParentiOS/Views/Components/PointsBalanceCard.swift` (~80 LOC)
3. `apps/ParentiOS/Views/Components/LearningTimeCard.swift` (~80 LOC)
4. `apps/ParentiOS/Views/Components/RedemptionsCard.swift` (~80 LOC)
5. `apps/ParentiOS/Views/Components/ShieldStatusCard.swift` (~80 LOC)
6. `apps/ParentiOS/ViewModels/DashboardViewModel.swift` (~150 LOC)
7. `Sources/Core/DataExporter.swift` (~100 LOC)
8. `extensions/DeviceActivityReportExtension/WeeklyReportView.swift` (~120 LOC)

**Files to Modify:**
- `apps/ParentiOS/ClaudexApp.swift` — Add dashboard navigation

---

## Mock Data Strategy

Since we can't test DeviceActivity without entitlement, create mock data layer:

```swift
protocol DashboardDataSource {
    func getBalance(childId: ChildID) -> Int
    func getTodayPoints(childId: ChildID) -> Int
    func getTodayLearningMinutes(childId: ChildID) -> Int
    // ... etc
}

// Real implementation
class LiveDashboardDataSource: DashboardDataSource {
    let ledger: PointsLedger
    let engine: PointsEngine
    // Uses real services
}

// Mock for testing/preview
class MockDashboardDataSource: DashboardDataSource {
    // Returns sample data
}
```

---

## Implementation Checklist

- [ ] Create DashboardViewModel with data aggregation
- [ ] Build PointsBalanceCard UI component
- [ ] Build LearningTimeCard UI component
- [ ] Build RedemptionsCard UI component
- [ ] Build ShieldStatusCard UI component
- [ ] Implement refresh logic (pull-to-refresh, auto-refresh)
- [ ] Create DataExporter for CSV format
- [ ] Create DataExporter for JSON format
- [ ] Add share sheet integration
- [ ] Create DeviceActivityReport extension target
- [ ] Implement WeeklyReportView in extension
- [ ] Add adaptive layout for iPad
- [ ] Test on different device sizes
- [ ] Add SwiftUI previews with mock data
- [ ] Update navigation in ClaudexApp.swift

---

## Success Criteria

✅ **Functional:**
- Dashboard loads quickly (<1s)
- All data accurately reflects engine state
- Export produces valid CSV/JSON
- Weekly report shows aggregated data
- Works on iPhone and iPad

✅ **Quality:**
- Clean, readable UI following iOS design patterns
- Proper error states and loading indicators
- Accessibility labels for VoiceOver
- Dynamic Type support

✅ **Performance:**
- No lag when scrolling
- Efficient data queries
- Minimal re-renders

---

## Next Steps After EP-07

1. **EP-08:** Notifications (weekly summaries, alerts)
2. **EP-03:** App categorization UI
3. **EP-06:** CloudKit sync for multi-parent

The dashboard provides the visibility layer while waiting for entitlement approval to test the full device integration!

