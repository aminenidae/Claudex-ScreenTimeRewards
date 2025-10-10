# CloudKit Schema Design

## Overview

This document defines the CloudKit schema for Claudex Screen Time Rewards, supporting multi-parent sync, audit logging, and offline reconciliation with last-writer-wins conflict resolution.

## Container & Database

- **Container:** `iCloud.com.claudex.screentimerewards`
- **Database:** Private Database (user-scoped data)
- **Zone:** Custom zone `FamilyZone` (enables atomic batch operations and change tracking)

## Record Types

### 1. Family

Root record for family data. One per family.

| Field | Type | Indexed | Description |
|-------|------|---------|-------------|
| `recordName` | String (PK) | ✓ | UUID for family |
| `createdAt` | Date | ✓ | Family creation timestamp |
| `parentDeviceIds` | [String] | - | List of parent device IDs |
| `familyName` | String | - | Optional family display name |
| `modifiedAt` | Date | ✓ | Last modification (for sync) |

**Indexes:**
- `createdAt` (queryable)
- `modifiedAt` (for change tracking)

---

### 2. ChildContext

Represents a child in the family. Multiple per family.

| Field | Type | Indexed | Description |
|-------|------|---------|-------------|
| `recordName` | String (PK) | ✓ | ChildID.rawValue |
| `familyRef` | Reference | ✓ | → Family record |
| `childOpaqueId` | String | - | Apple's opaque child identifier |
| `displayName` | String | - | Child's name (optional) |
| `pairedDeviceIds` | [String] | - | Child device IDs |
| `storeName` | String | - | Local storage identifier |
| `createdAt` | Date | - | Child addition timestamp |
| `modifiedAt` | Date | ✓ | Last modification |

**Indexes:**
- `familyRef` (for family queries)
- `modifiedAt` (for change tracking)

**Delete Rule:** Family deletion cascades to children (via client-side logic)

---

### 3. AppRule

Per-child app categorization rules (Learning/Reward).

| Field | Type | Indexed | Description |
|-------|------|---------|-------------|
| `recordName` | String (PK) | ✓ | `{childID}:{appToken}` |
| `familyRef` | Reference | ✓ | → Family record |
| `childRef` | Reference | ✓ | → ChildContext record |
| `appToken` | String | ✓ | FamilyActivitySelection token |
| `classification` | String | ✓ | "learning" or "reward" |
| `isCategory` | Bool | - | True if category, false if individual app |
| `categoryId` | String | - | ActivityCategory identifier (if isCategory) |
| `createdAt` | Date | - | Rule creation timestamp |
| `modifiedAt` | Date | ✓ | Last modification |
| `modifiedBy` | String | - | Parent device ID |

**Indexes:**
- `familyRef` + `childRef` (compound for per-child queries)
- `childRef` (for single-child rule fetches)
- `appToken` (for deduplication checks)
- `classification` (for filtering learning vs reward)

**Conflict Resolution:** Last-writer-wins based on `modifiedAt`

---

### 4. ChildAppInventory

Per-child app inventory from child devices (tracks what apps are actually installed).

| Field | Type | Indexed | Description |
|-------|------|---------|-------------|
| `recordName` | String (PK) | ✓ | `{childID}:{deviceID}` |
| `familyRef` | Reference | ✓ | → Family record |
| `childRef` | Reference | ✓ | → ChildContext record |
| `deviceId` | String | ✓ | Child device identifier |
| `appTokens` | [String] | - | Base64-encoded ApplicationTokens |
| `categoryTokens` | [String] | - | Base64-encoded CategoryTokens |
| `lastUpdated` | Date | ✓ | Last sync timestamp |
| `appCount` | Int64 | - | Total count (apps + categories) |

**Indexes:**
- `familyRef` + `childRef` (compound for per-child queries)
- `childRef` (for single-child inventory fetch)
- `deviceId` (for per-device tracking)
- `lastUpdated` (for freshness checks)

**Purpose:**
- Child devices report their installed apps to CloudKit
- Parent devices fetch inventory to filter FamilyActivityPicker
- Enables "Show only child's apps" filter in parent UI
- Updated on: child app launch, app installation, periodic sync (24h)

**Conflict Resolution:** Last-writer-wins based on `lastUpdated`

**Notes:**
- One record per child device (supports multiple devices per child)
- `appTokens` and `categoryTokens` are opaque tokens from FamilyControls
- Parent UI merges inventories from all child devices (union)

---

### 5. PointsLedgerEntry

Append-only ledger for points transactions.

| Field | Type | Indexed | Description |
|-------|------|---------|-------------|
| `recordName` | String (PK) | ✓ | Entry UUID |
| `familyRef` | Reference | ✓ | → Family record |
| `childRef` | Reference | ✓ | → ChildContext record |
| `type` | String | ✓ | "accrual", "redemption", "adjustment" |
| `amount` | Int64 | - | Points amount (signed) |
| `timestamp` | Date | ✓ | Transaction timestamp |
| `reason` | String | - | For adjustments (optional) |
| `deviceId` | String | - | Originating device |
| `syncedAt` | Date | - | When synced to CloudKit |

**Indexes:**
- `familyRef` + `childRef` (compound)
- `childRef` + `timestamp` (for chronological queries)
- `type` (for filtering by transaction type)

**Notes:**
- Append-only: Never delete or modify after creation
- `syncedAt` tracks when local → cloud sync occurred
- Balance is computed client-side by summing entries

---

### 6. AuditEntry

Audit log for administrative actions.

| Field | Type | Indexed | Description |
|-------|------|---------|-------------|
| `recordName` | String (PK) | ✓ | Entry UUID |
| `familyRef` | Reference | ✓ | → Family record |
| `childRef` | Reference | - | → ChildContext (nullable) |
| `action` | String | ✓ | Action type (e.g., "rule_changed") |
| `timestamp` | Date | ✓ | Action timestamp |
| `actorDeviceId` | String | - | Which parent device made change |
| `metadata` | String | - | JSON-encoded details |

**Indexes:**
- `familyRef` (all family audits)
- `action` (filter by action type)
- `timestamp` (chronological order)

**Notes:**
- Append-only
- `metadata` stores action-specific details as JSON

---

### 7. RedemptionWindow

Active earned-time windows (for multi-device coordination).

| Field | Type | Indexed | Description |
|-------|------|---------|-------------|
| `recordName` | String (PK) | ✓ | Window UUID |
| `familyRef` | Reference | ✓ | → Family record |
| `childRef` | Reference | ✓ | → ChildContext record |
| `startTime` | Date | ✓ | Window start timestamp |
| `durationSeconds` | Double | - | Total window duration |
| `expiresAt` | Date | ✓ | Computed expiry (startTime + duration) |
| `pointsSpent` | Int64 | - | Points deducted |
| `isActive` | Bool | ✓ | True if not expired |
| `deviceId` | String | - | Device that initiated redemption |
| `createdAt` | Date | - | Record creation |

**Indexes:**
- `childRef` + `isActive` (for active window queries)
- `expiresAt` (for expiry cleanup)

**Lifecycle:**
- Created on redemption
- Marked `isActive = false` after expiry
- Cleaned up after 7 days (optional)

---

## Schema Evolution & Migration

### Version 1 (MVP)
- Initial schema as documented above
- No migration needed

### Future Versions
- Use CloudKit schema migration (add fields, never remove)
- Client-side compatibility checks via `schemaVersion` field on Family record

---

## Sync Strategy

### Last-Writer-Wins (LWW)
- All mutable records have `modifiedAt` timestamp
- On conflict, compare `modifiedAt`:
  - Server timestamp > Local timestamp → Server wins
  - Local timestamp > Server timestamp → Local wins (force push)
- Append-only records (Ledger, Audit) never conflict

### Change Tracking
- Use `CKQuerySubscription` on `modifiedAt` for push notifications
- Fetch changes via `CKFetchRecordZoneChangesOperation` with server change tokens
- Store last sync token locally for incremental sync

### Offline Queue
- Local SQLite queue for unsent changes
- Retry failed operations with exponential backoff
- Mark as synced only after CloudKit confirmation

---

## Performance Optimizations

### Batch Operations
- Use `CKModifyRecordsOperation` for bulk saves (max 400 records)
- Batch ledger entry uploads during sync

### Indexes
- Compound indexes for common queries (e.g., `childRef` + `timestamp`)
- Limit query results with `resultsLimit` (default 100)

### Query Limits
- Dashboard queries: Last 30 days only
- Ledger queries: Paginate with cursor-based pagination
- Audit logs: Parent-facing only, limit to 500 most recent

---

## Security & Privacy

### Access Control
- Private database only (no shared zones)
- Family data isolated per iCloud account
- No cross-family queries possible

### Data Retention
- Ledger entries: Indefinite (user export/delete option)
- Audit logs: 90 days rolling window
- Expired redemption windows: 7 days

### Encryption
- CloudKit encrypts at rest automatically
- No additional client-side encryption needed for MVP

---

## API Design Patterns

### Fetch Family Data
```swift
// 1. Fetch Family record by known ID
// 2. Fetch all ChildContext records where familyRef == familyID
// 3. Fetch all AppRule records where familyRef == familyID
// 4. Fetch recent PointsLedgerEntry records (last 30 days)
```

### Sync Flow
```swift
// 1. Check for network connectivity
// 2. Fetch server changes since last sync token
// 3. Merge server changes with local state (LWW)
// 4. Push local changes to server
// 5. Update sync token
// 6. Persist offline queue (if push failed)
```

### Conflict Resolution Example
```swift
if serverRecord.modifiedAt > localRecord.modifiedAt {
    // Server wins: Apply server record locally
    applyServerUpdate(serverRecord)
} else {
    // Local wins: Force push local record
    saveToCloudKit(localRecord, policy: .changedKeys)
}
```

---

## Testing Strategy

### Unit Tests
- CKRecord ↔ Model mapping (CloudKitMapper)
- Conflict resolution logic
- Offline queue persistence

### Integration Tests
- Mock CKContainer for sync operations
- Simulate network failures
- Test concurrent modifications from multiple devices

### Manual Testing
- Two-device test: Parent A and Parent B make simultaneous changes
- Offline → Online transition with queued changes
- Family deletion cascades to all child records

---

## Next Steps

1. ✅ Define schema (this document)
2. ⬜ Implement missing mappers (Family, AppRule, RedemptionWindow)
3. ⬜ Create SyncService with change tracking
4. ⬜ Add offline queue with SQLite persistence
5. ⬜ Write unit tests for mappers and sync logic
6. ⬜ Integration testing with CloudKit Development environment
