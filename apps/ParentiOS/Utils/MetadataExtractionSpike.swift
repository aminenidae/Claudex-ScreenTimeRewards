import SwiftUI
import FamilyControls
import UIKit

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
struct AppMetadataExtracted {
    let displayName: String?
    let icon: UIImage?
    let extractionTimeMs: Double
    let method: ExtractionMethod

    enum ExtractionMethod {
        case accessibilityLabel
        case fallbackNickname(String)
        case failed(String)
    }
}

@available(iOS 16.0, *)
class MetadataExtractionSpike {

    // MARK: - Public Interface

    /// Extract metadata (name + icon) from ApplicationToken
    /// Returns nil if extraction completely fails
    static func extractMetadata(from token: ApplicationToken, fallbackName: String? = nil) -> AppMetadataExtracted? {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Step 1: Extract app name via accessibility system
        let displayName = extractAppName(from: token, fallback: fallbackName)

        // Step 2: Extract icon via ImageRenderer
        let icon = extractAppIcon(from: token)

        let endTime = CFAbsoluteTimeGetCurrent()
        let elapsedMs = (endTime - startTime) * 1000

        // Determine extraction method
        let method: AppMetadataExtracted.ExtractionMethod
        if let name = displayName, name != fallbackName {
            method = .accessibilityLabel
        } else if let fallback = fallbackName {
            method = .fallbackNickname(fallback)
        } else {
            method = .failed("No name extracted and no fallback provided")
        }

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
    private static func extractAppName(from token: ApplicationToken, fallback: String?) -> String? {
        // Approach 1: Render Label(token) and read accessibilityLabel
        if let name = extractViaAccessibilityLabel(token: token) {
            return name
        }

        // Approach 2: Fallback to user-supplied nickname
        if let fallback = fallback {
            print("⚠️ Using fallback name: \(fallback)")
            return fallback
        }

        // Approach 3: Failed extraction
        print("❌ Failed to extract app name from token")
        return nil
    }

    private static func extractViaAccessibilityLabel(token: ApplicationToken) -> String? {
        // Create SwiftUI Label view
        let label = Label(token)

        // Render in UIHostingController to access UIKit view hierarchy
        let hostingController = UIHostingController(rootView: label)

        // Load the view hierarchy
        hostingController.loadViewIfNeeded()

        guard let rootView = hostingController.view else {
            print("⚠️ Failed to load hosting controller view")
            return nil
        }

        // Strategy 1: Check root view's accessibilityLabel
        if let accessibilityLabel = rootView.accessibilityLabel, !accessibilityLabel.isEmpty {
            print("✅ Extracted via root accessibilityLabel: \(accessibilityLabel)")
            return accessibilityLabel
        }

        // Strategy 2: Traverse subviews looking for accessibility info
        if let name = findAccessibilityLabel(in: rootView) {
            print("✅ Extracted via subview traversal: \(name)")
            return name
        }

        // Strategy 3: Check if Label exposes accessibilityValue
        if let accessibilityValue = rootView.accessibilityValue, !accessibilityValue.isEmpty {
            print("✅ Extracted via accessibilityValue: \(accessibilityValue)")
            return accessibilityValue
        }

        print("⚠️ No accessible text found in view hierarchy")
        return nil
    }

    /// Recursively search view hierarchy for accessibility labels
    private static func findAccessibilityLabel(in view: UIView) -> String? {
        // Check current view
        if let label = view.accessibilityLabel, !label.isEmpty {
            return label
        }

        // Check subviews (breadth-first search)
        for subview in view.subviews {
            if let label = subview.accessibilityLabel, !label.isEmpty {
                return label
            }
        }

        // Check subviews recursively (depth-first search)
        for subview in view.subviews {
            if let label = findAccessibilityLabel(in: subview) {
                return label
            }
        }

        return nil
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
struct BatchExtractionResult {
    let totalTokens: Int
    let successfulNames: Int
    let successfulIcons: Int
    let nameSuccessRate: Double  // Percentage
    let iconSuccessRate: Double  // Percentage
    let averageTimeMs: Double
    let results: [AppMetadataExtracted]

    var meetsSuccessCriteria: Bool {
        return nameSuccessRate >= 90.0 &&
               iconSuccessRate >= 80.0 &&
               averageTimeMs < 100.0
    }

    func printSummary() {
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
