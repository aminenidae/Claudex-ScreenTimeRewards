import SwiftUI
import FamilyControls
import UIKit
#if canImport(ManagedSettings)
import ManagedSettings
#endif

/// Spike implementation to test metadata extraction from ApplicationToken
/// Based on specialist recommendation: accessibilityLabel + ImageRenderer
///
/// **Goal:** Validate that we can extract app name + icon without private APIs
///
/// **Approach:**
/// 1. Render Label(token) in UIHostingController
/// 2. Extract app name from view.accessibilityLabel
/// 3. Capture icon using ImageRenderer (iOS 16+)
///
/// **Success Criteria:**
/// - Extract names for 90%+ of apps
/// - Extract icons for 80%+ of apps
/// - Performance < 100ms per app
/// - No crashes, no private APIs

@available(iOS 16.0, *)
public struct AppMetadataExtracted {
    public let displayName: String?
    public let icon: UIImage?
    public let extractionTimeMs: Double
    public let method: ExtractionMethod

    public enum ExtractionMethod {
        case accessibilityLabel
        case managedSettingsFallback
        case fallbackNickname(String)
        case failed(String)
    }
}

@available(iOS 16.0, *)
@MainActor
public class MetadataExtractionSpike {

    // MARK: - Public Interface

    /// Extract metadata (name + icon) from ApplicationToken
    /// Returns nil if extraction completely fails
    public static func extractMetadata(from token: ApplicationToken, fallbackName: String? = nil) -> AppMetadataExtracted? {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Step 1: Extract app name via accessibility system
        var displayName: String? = nil
        var method: AppMetadataExtracted.ExtractionMethod = .failed("Accessibility extraction did not return a name")

        if let accessibleName = extractAppName(from: token) {
            displayName = accessibleName
            method = .accessibilityLabel
        }

        // Step 2: Extract icon via ImageRenderer
        var icon = extractAppIcon(from: token)

        #if canImport(ManagedSettings)
        let application = ManagedSettings.Application(token: token)

        if displayName == nil, let managedName = application.localizedDisplayName ?? application.bundleIdentifier {
            displayName = managedName
            method = .managedSettingsFallback
        }

        #endif

        // Step 4: user-provided fallback nickname
        if displayName == nil, let fallback = fallbackName {
            displayName = fallback
            method = .fallbackNickname(fallback)
        }

        if displayName == nil {
            method = .failed("No name extracted and no fallback provided")
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let elapsedMs = (endTime - startTime) * 1000

        print("📊 Metadata extraction: \(displayName ?? "nil") in \(String(format: "%.1f", elapsedMs))ms")

        return AppMetadataExtracted(
            displayName: displayName,
            icon: icon,
            extractionTimeMs: elapsedMs,
            method: method
        )
    }

    // MARK: - Name Extraction (Accessibility Label Approach)

    /// Extract app name from ApplicationToken via accessibility system
    /// This is the KEY INNOVATION from specialist recommendation
    private static func extractAppName(from token: ApplicationToken) -> String? {
        // Approach 1: Render Label(token) and read accessibilityLabel
        if let name = extractViaAccessibilityLabel(token: token) {
            return name
        }

        // Failed extraction
        print("❌ Failed to extract app name from accessibility traversal")
        return nil
    }

    private static func extractViaAccessibilityLabel(token: ApplicationToken) -> String? {
        guard let activeWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else {
            print("⚠️ No active window available for accessibility rendering")
            return nil
        }

        guard let windowScene = activeWindow.windowScene else {
            print("⚠️ Active window has no associated scene; cannot host label")
            return nil
        }

        let tempWindow = UIWindow(windowScene: windowScene)
        tempWindow.windowLevel = activeWindow.windowLevel + 1
        tempWindow.alpha = 0.001
        tempWindow.isUserInteractionEnabled = false

        let containerController = UIViewController()
        containerController.view.backgroundColor = .clear
        tempWindow.rootViewController = containerController

        let hostingController = UIHostingController(rootView: Label(token))
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        containerController.addChild(hostingController)
        containerController.view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: containerController.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerController.view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: containerController.view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerController.view.bottomAnchor)
        ])
        hostingController.didMove(toParent: containerController)

        tempWindow.isHidden = false
        tempWindow.makeKey()
        containerController.view.layoutIfNeeded()

        // Allow the run loop to advance briefly so accessibility metadata is populated
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))

        let cleanup: () -> Void = {
            hostingController.willMove(toParent: nil)
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
            tempWindow.isHidden = true
            tempWindow.rootViewController = nil
            activeWindow.makeKey()
        }

        guard let rootView = hostingController.view else {
            print("⚠️ Hosting controller view unavailable for accessibility traversal")
            cleanup()
            return nil
        }

        if let text = extractAccessibilityText(from: rootView) {
            print("✅ Extracted accessibility text: \(text)")
            cleanup()
            return text
        }

        if let name = findAccessibilityLabel(in: rootView) {
            print("✅ Extracted via subview traversal: \(name)")
            cleanup()
            return name
        }

        print("⚠️ No accessible text found in view hierarchy")
        cleanup()
        return nil
    }

    /// Recursively search view hierarchy for accessibility labels or attributed strings
    private static func findAccessibilityLabel(in view: UIView) -> String? {
        if let text = extractAccessibilityText(from: view) {
            return text
        }

        // Check subviews (breadth-first search) for a quick match
        for subview in view.subviews {
            if let text = extractAccessibilityText(from: subview) {
                return text
            }
        }

        // Fall back to deep traversal if nothing surfaced yet
        for subview in view.subviews {
            if let label = findAccessibilityLabel(in: subview) {
                return label
            }
        }

        return nil
    }

    /// Extract any accessible text associated with a view or its delegated elements
    private static func extractAccessibilityText(from view: UIView) -> String? {
        if let label = normalizedAccessibilityString(view.accessibilityLabel) {
            return label
        }

        if let attributedLabel = normalizedAccessibilityString(view.accessibilityAttributedLabel?.string) {
            return attributedLabel
        }

        if let value = normalizedAccessibilityString(view.accessibilityValue) {
            return value
        }

        if let attributedValue = normalizedAccessibilityString(view.accessibilityAttributedValue?.string) {
            return attributedValue
        }

        if let elementText = textFromAccessibilityElements(of: view) {
            return elementText
        }

        return nil
    }

    /// Inspect accessibilityElements array for text the SwiftUI bridge might expose
    private static func textFromAccessibilityElements(of view: UIView) -> String? {
        guard let elements = view.accessibilityElements else { return nil }

        for element in elements {
            if let subview = element as? UIView, let text = extractAccessibilityText(from: subview) {
                return text
            }

            if let accessibilityElement = element as? UIAccessibilityElement {
                if let label = normalizedAccessibilityString(accessibilityElement.accessibilityLabel) {
                    return label
                }

                if let attributedLabel = normalizedAccessibilityString(accessibilityElement.accessibilityAttributedLabel?.string) {
                    return attributedLabel
                }

                if let value = normalizedAccessibilityString(accessibilityElement.accessibilityValue as? String) {
                    return value
                }

                if let attributedValue = normalizedAccessibilityString(accessibilityElement.accessibilityAttributedValue?.string) {
                    return attributedValue
                }
            }
        }

        return nil
    }

    /// Normalize accessibility strings so blank values are filtered out
    private static func normalizedAccessibilityString(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    // MARK: - Icon Extraction (ImageRenderer Approach)

    /// Extract app icon from ApplicationToken via ImageRenderer (iOS 16+)
    private static func extractAppIcon(from token: ApplicationToken) -> UIImage? {
        // Create SwiftUI Label view
        let label = Label(token)

        // Use ImageRenderer to capture the view as an image
        let renderer = ImageRenderer(content: label)

        // Set appropriate scale for retina displays
        renderer.scale = UIScreen.main.scale

        // Capture the image
        guard let uiImage = renderer.uiImage else {
            print("⚠️ ImageRenderer failed to capture icon")
            return nil
        }

        // Resize to standard size (60x60 as recommended by specialist)
        let resized = resizeImage(uiImage, targetSize: CGSize(width: 60, height: 60))

        print("✅ Extracted icon: \(resized.size.width)x\(resized.size.height) @ \(resized.scale)x scale")
        return resized
    }

    /// Resize UIImage to target size
    private static func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    // MARK: - Batch Extraction

    /// Extract metadata for multiple tokens (for testing)
    /// Returns statistics about success rate and performance
    static func extractBatch(tokens: [ApplicationToken], fallbackNames: [String]? = nil) -> BatchExtractionResult {
        var results: [AppMetadataExtracted] = []
        var successfulNames = 0
        var successfulIcons = 0
        var totalTimeMs: Double = 0

        for (index, token) in tokens.enumerated() {
            let fallback = fallbackNames?[safe: index]

            guard let metadata = extractMetadata(from: token, fallbackName: fallback) else {
                print("❌ Failed to extract metadata for token \(index)")
                continue
            }

            results.append(metadata)

            if metadata.displayName != nil {
                successfulNames += 1
            }
            if metadata.icon != nil {
                successfulIcons += 1
            }
            totalTimeMs += metadata.extractionTimeMs
        }

        let total = tokens.count
        let nameSuccessRate = total > 0 ? (Double(successfulNames) / Double(total)) * 100 : 0
        let iconSuccessRate = total > 0 ? (Double(successfulIcons) / Double(total)) * 100 : 0
        let avgTimeMs = total > 0 ? totalTimeMs / Double(total) : 0

        return BatchExtractionResult(
            totalTokens: total,
            successfulNames: successfulNames,
            successfulIcons: successfulIcons,
            nameSuccessRate: nameSuccessRate,
            iconSuccessRate: iconSuccessRate,
            averageTimeMs: avgTimeMs,
            results: results
        )
    }
}

// MARK: - Supporting Types

@available(iOS 16.0, *)
public struct BatchExtractionResult {
    public let totalTokens: Int
    public let successfulNames: Int
    public let successfulIcons: Int
    public let nameSuccessRate: Double  // Percentage
    public let iconSuccessRate: Double  // Percentage
    public let averageTimeMs: Double
    public let results: [AppMetadataExtracted]

    public var meetsSuccessCriteria: Bool {
        return nameSuccessRate >= 90.0 &&
               iconSuccessRate >= 80.0 &&
               averageTimeMs < 100.0
    }

    public func printSummary() {
        print("\n" + String(repeating: "=", count: 60))
        print("📊 METADATA EXTRACTION SPIKE RESULTS")
        print(String(repeating: "=", count: 60))
        print("Total tokens tested: \(totalTokens)")
        print("Successful name extraction: \(successfulNames)/\(totalTokens) (\(String(format: "%.1f", nameSuccessRate))%)")
        print("Successful icon extraction: \(successfulIcons)/\(totalTokens) (\(String(format: "%.1f", iconSuccessRate))%)")
        print("Average extraction time: \(String(format: "%.1f", averageTimeMs))ms per app")
        print("")
        print("Success Criteria (90% names, 80% icons, <100ms):")
        print(meetsSuccessCriteria ? "✅ PASSED" : "❌ FAILED")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
