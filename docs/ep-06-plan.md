# EP-06 — Sync & Multi-Parent (CloudKit, Conflicts, Audit)

## Story Tracker

| Story | Title | Status | Notes |
| --- | --- | --- | --- |
| S-601 | CloudKit Schema Implementation | In progress | Mapper helpers for ChildContext, PointsLedgerEntry, AuditEntry added; AppRule mapping pending. |
| S-602 | Conflict Strategy (LWW with Timestamps) | Not started | Define merge policy and test multi-parent edits. |
| S-603 | Offline Queue & Replay | Not started | Prototype local queue for offline updates. |
| S-604 | Audit Log Usability | Not started | Surface audit trail UI using new AuditLog data. |
| S-605 | Performance Targets | Not started | Measure sync latency (<2s online) and local operations (<200ms). |

## P0 Spikes

### P0-A: CloudKit Record Prototyping
- Goal: Round-trip CKRecords for `ChildContext`, `AppRule`, `PointsLedgerEntry`, `AuditEntry`.
- Status: ChildContext/PointsLedgerEntry/AuditEntry helpers implemented in `Sources/SyncKit/CloudKitMapper.swift` with unit tests. AppRule serialization TBD.
- Next tasks:
  - Add mapping for AppRule/ShieldPolicy selections.
  - Validate data round-trip with simulated CKRecord references.
- Outputs: Code in SyncKit mapper, tests in `CloudKitMapperTests`. Update feasibility doc after AppRule mapping.

### P0-B: Conflict Resolution Strategy
- Goal: Verify last-writer-wins with timestamp comparison works for multi-parent edits.
- Tasks:
  - Simulate concurrent edits to rules/ledger entries.
  - Document merge behavior and edge cases (e.g., same timestamp).
  - Decide when to surface conflicts in UI.
- Outputs: Update `docs/data-model.md` with merge policy.

### P0-C: Offline Queue Prototype
- Goal: Ensure edits captured offline replay once network is available.
- Tasks:
  - Implement simple operation queue with retry/backoff.
  - Test toggling Airplane Mode to confirm replay.
  - Log failures for later inspection.

## Implementation Outline

1. **SyncKit Module**
   - Add `CloudKitSyncService` responsible for CRUD operations per record type.
   - Wrap operations in async/await APIs for UI usage.

2. **Data Mapping**
   - Extend existing models with `init(record:)` / `toRecord()` helpers.
   - Handle FamilyActivitySelection token serialization via Data blobs.

3. **Audit Log Surfacing**
   - Persist audit entries to CloudKit alongside local storage.
   - Add parent-mode UI to review entries (filter by child and action).

4. **Testing**
   - Unit tests for serialization logic (CKRecord ↔︎ model).
   - Integration tests using `CKDatabaseScope.private` with mockable dependencies.

## References
- `docs/data-model.md` — Record definitions & uniqueness constraints.
- `docs/checklists.md` — EP-06 checklist items.
- `docs/progress-log.md` — Prior work on points/redemption (dependencies for sync).
