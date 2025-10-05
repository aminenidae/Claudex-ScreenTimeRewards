# UX Copy & Messaging

## Authorization & Revocation (Parent Mode)

- Banner titles:
  - Approved: "Family Controls authorized"
  - Not determined: "Authorization required"
  - Denied/Revoked: "Authorization denied"
  - Error: "Authorization error"

- Body copy:
  - Required: "Parents must grant Family Controls access before linking child devices."
  - Denied/Revoked: "Authorization was declined or revoked. Open Settings → Screen Time → Apps to grant access."
  - Restricted: *Not currently used.*
  - Error: "Error requesting access: {error}"

- Action button:
  - Label: "Request Access"
  - Disabled once state is `.approved`.

## Add Child Flow

- Sheet title: "Add Child"
- Text field placeholder: "Child name"
- Confirmation action: "Link"
- Error message examples:
  - `FamilyControlsError.invalidAccountType`: "Requires an organizer/guardian account with Family Sharing."
  - `FamilyControlsError.authorizationConflict`: "A conflicting authorization exists. Try again."
  - Other errors: fallback to `error.localizedDescription`.

## Dashboard Cards

- Points Balance Card:
  - Title: "Points Balance"
  - Subtitle: "Points earned today"
- Learning Time Card:
  - Title: "Learning Time"
  - Body: "Today" / "Last 7 days"
- Redemptions Card:
  - Title: "Redemptions"
  - Active time label: "Active Reward Time"
  - Inactive message: "No active reward time"
  - Action button: "Redeem time"
- Shield Status Card:
  - States: "Reward apps locked" / "Reward apps unlocked"

