# Project Overview: Claudex Screen Time Rewards

This project is an iOS/iPadOS application designed for reward-based screen time management for families. It leverages Apple's Screen Time APIs (FamilyControls, ManagedSettings, DeviceActivity) to monitor app usage, award points for "learning" app engagement, and allow children to redeem these points for temporary access to "reward" apps. The application supports distinct Parent and Child modes and utilizes CloudKit for data synchronization across devices.

**Key Features:**
*   **Reward-Based System:** Incentivizes educational app usage by allowing children to earn points for screen time.
*   **Parental Controls:** Parents can categorize apps, configure point accrual rates, and manage redemptions.
*   **Screen Time API Integration:** Deep integration with Apple's Family Controls, Managed Settings, and Device Activity frameworks for robust screen time management.
*   **Multi-Device & Multi-User Support:** Designed for use by multiple family members across various iOS/iPadOS devices, with CloudKit for data sync.
*   **Privacy-First:** Emphasizes data minimization and avoids third-party tracking in child contexts.

**Core Technologies:**
*   **Swift & SwiftUI:** Primary language and UI framework for the iOS application.
*   **Apple Screen Time APIs:** `FamilyControls`, `ManagedSettings`, `DeviceActivity`, `DeviceActivityReport Extension` for core functionality.
*   **CloudKit:** Used for secure and private data synchronization and storage.

**Architecture:**
The project is structured into several modular Swift packages:
*   `Core`: Contains fundamental data models and shared utilities.
*   `ScreenTimeService`: Encapsulates logic for interacting with Apple's Screen Time APIs, including authorization and monitoring.
*   `PointsEngine`: Manages the logic for point accrual, redemption, and ledger management.
*   `SyncKit`: Handles data synchronization, primarily with CloudKit.

The application features a `ModeSelectionView` at launch, allowing users to switch between Parent and Child modes, each with distinct functionalities and access levels.

# Building and Running

This is an Xcode project. To build and run the application:

1.  **Open in Xcode:** Open `ClaudexScreenTimeRewards.xcodeproj` in Xcode.
2.  **Select Target:** Choose the `ParentiOS` target for the main application.
3.  **Provisioning:** Ensure you have appropriate Apple Developer Program provisioning profiles configured, especially for Family Controls entitlements.
4.  **Run:** Build and run the application on an iOS 16+ device or simulator.

**Important Notes:**
*   The application requires the `com.apple.developer.family-controls` entitlement, which needs to be requested and approved by Apple.
*   Some features, particularly those involving Screen Time APIs, may require running on a physical device with appropriate permissions.

# Development Conventions

*   **Modular Design:** The codebase is organized into distinct Swift packages for better maintainability and separation of concerns.
*   **Issue Tracking:** GitHub issues are used for tracking development, with epics (e.g., `EP-01`) and stories defined in `PRD.md` and managed via scripts like `scripts/seed_epics.sh`.
*   **Testing:** Unit tests are present in the `Tests/CoreTests` directory, covering core logic like `PointsEngine` and `SyncKit` components.
*   **Documentation:** Key planning and feasibility documents are located in the `docs/` directory, including `PRD.md` and `docs/feasibility.md`.
*   **SwiftUI First:** The UI is primarily built using SwiftUI, with a focus on adapting to different device sizes and modes.
*   **Privacy & Security:** Adherence to Apple's guidelines for parental control apps, including data minimization and secure storage practices.
