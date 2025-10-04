# Data Model (CloudKit) — MVP Draft

This document defines initial CloudKit record types, fields, indexes, and guidance for sync/conflict handling. The model is privacy-first and stores aggregates where possible.

## CloudKit Scope

- Container: 1 CloudKit container for the app.
- Databases:
  - Shared Database: Primary store for Family-scoped data (preferred for multi-parent access).
  - Private Database: Device-local caches and ephemeral state as needed; avoid PII.
- Sharing: Parent Admin creates Family records and shares with Co-Parent and (optionally) Child Apple IDs in the family.

## Record Types

Note: CKRecord field types are shown in parentheses; all records include `createdAt` and `updatedAt` timestamps. Use server timestamps on save where possible.

### Family
- id (CKRecord.ID; recordName is UUID)
- code (String, optional invite/pairing code; ephemeral)
- settingsVersion (Int)

Indexes
- By recordName (default)

### ParentProfile
- familyRef (Reference → Family; required)
- role (String: "admin"|"co_parent")
- deviceIds (String List, optional)

Indexes
- familyRef

### ChildContext
- familyRef (Reference → Family; required)
- childOpaqueId (String; opaque identifier from Screen Time APIs)
- displayName (String, optional; local nickname, avoid PII)
- pairedDeviceIds (String List, optional)

Constraints
- Uniqueness: (familyRef, childOpaqueId)

Indexes
- familyRef
- childOpaqueId

### AppRule
- familyRef (Reference → Family; required)
- bundleId (String)
- classification (String: "learning"|"reward")
- source (String: "default"|"override")

Constraints
- Uniqueness: (familyRef, bundleId)

Indexes
- familyRef
- bundleId

### PointsLedgerEntry
- familyRef (Reference → Family; required)
- childRef (Reference → ChildContext; required)
- type (String: "accrual"|"redemption"|"adjustment")
- amount (Int; points, positive integers only)
- timestamp (Date)
- reason (String, optional)
- actorParentRef (Reference → ParentProfile, optional)

Retention
- Keep 90 days in detail; periodically roll up to weekly aggregates (and prune old entries) to minimize footprint.

Indexes
- familyRef
- childRef
- timestamp (descending)

### EarnedTimeBalance
- childRef (Reference → ChildContext; required)
- balanceSeconds (Int)
- updatedAt (Date)

Constraints
- One per childRef

Indexes
- childRef

### ShieldPolicy
- familyRef (Reference → Family; required)
- rewardCategories (String List; Apple category identifiers)
- rewardApps (String List; bundle IDs)

Indexes
- familyRef

### AuditEntry
- familyRef (Reference → Family; required)
- actorParentRef (Reference → ParentProfile; required)
- action (String)
- target (String)
- timestamp (Date)
- metadata (String, JSON-encoded, optional)

Indexes
- familyRef
- timestamp (descending)

## Conflict Resolution & Sync

- Save Policy: Use `ifServerRecordUnchanged` where practical; on conflict, rebase client changes onto latest server record and retry.
- Strategy: Last-writer-wins using server timestamps; merge lists by union where appropriate (e.g., deviceIds), otherwise replace.
- Offline: Queue local changes; replay on reconnect. Ensure idempotent mutations with deterministic record IDs.
- Deletions: Soft-delete by tombstone when needed; garbage collect after grace period.

## Local Caching

- Maintain a local cache of Family, ChildContext, AppRule, EarnedTimeBalance for responsive UI.
- Cache invalidation via CKQuerySubscriptions or periodic background refresh.

## Privacy & Data Minimization

- Avoid raw per-event usage timelines; store aggregates and summarized deltas in ledger.
- Keep optional displayName local unless explicitly shared by parent; prefer device-local nicknames.
- Don’t store emails/Apple IDs; use CloudKit sharing and opaque identifiers instead.

## Migrations

- Version fields on records (e.g., settingsVersion) to support future schema evolution.
- Provide simple migration steps: create missing indexes, backfill aggregates, add new fields with sensible defaults.

## Queries (Examples)

- Fetch children in a family: `ChildContext WHERE familyRef = ?`
- Fetch rules: `AppRule WHERE familyRef = ?`
- Fetch ledger entries for a child (last 30 days): `PointsLedgerEntry WHERE childRef = ? AND timestamp > ? ORDER BY timestamp DESC`
- Fetch audit log (recent): `AuditEntry WHERE familyRef = ? ORDER BY timestamp DESC`

