import XCTest
import Core

final class PairingServiceTests: XCTestCase {
    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "PairingServiceTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create test user defaults")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    func testGeneratePairingCodeProvidesUniqueCode() throws {
        let defaults = makeUserDefaults()
        let service = PairingService(userDefaults: defaults)
        let childId = ChildID("child-001")

        let firstCode = try service.generatePairingCode(for: childId, ttlMinutes: 5)
        let secondCode = try service.generatePairingCode(for: childId, ttlMinutes: 5)

        XCTAssertEqual(firstCode.code.count, 6)
        XCTAssertEqual(secondCode.code.count, 6)
        XCTAssertNotEqual(firstCode.code, secondCode.code)
        XCTAssertEqual(service.activeCode(for: childId)?.code, secondCode.code)
    }

    @MainActor
    func testConsumePairingCodeCreatesPairing() throws {
        let defaults = makeUserDefaults()
        let service = PairingService(userDefaults: defaults)
        let childId = ChildID("child-002")
        let deviceId = "device-123"

        let code = try service.generatePairingCode(for: childId, ttlMinutes: 5)
        let pairing = try service.consumePairingCode(code.code, deviceId: deviceId)

        XCTAssertEqual(pairing.childId, childId)
        XCTAssertEqual(pairing.deviceId, deviceId)
        XCTAssertNotNil(service.getPairing(for: deviceId))
        XCTAssertNil(service.activeCode(for: childId))

        XCTAssertThrowsError(try service.consumePairingCode(code.code, deviceId: "another-device")) { error in
            guard case PairingError.codeAlreadyUsed = error else {
                return XCTFail("Expected codeAlreadyUsed, got \(error)")
            }
        }
    }

    @MainActor
    func testExpiredCodeCannotBeConsumed() throws {
        let defaults = makeUserDefaults()
        let service = PairingService(userDefaults: defaults)
        let childId = ChildID("child-003")
        let deviceId = "device-789"

        let code = try service.generatePairingCode(for: childId, ttlMinutes: 0)
        Thread.sleep(forTimeInterval: 0.05)

        XCTAssertThrowsError(try service.consumePairingCode(code.code, deviceId: deviceId)) { error in
            guard case PairingError.codeExpired = error else {
                return XCTFail("Expected codeExpired, got \(error)")
            }
        }
    }

    @MainActor
    func testGenerationRateLimiting() throws {
        let defaults = makeUserDefaults()
        let service = PairingService(userDefaults: defaults)
        let childId = ChildID("child-004")

        // First five generations should succeed
        for _ in 0..<5 {
            _ = try service.generatePairingCode(for: childId, ttlMinutes: 5)
        }

        XCTAssertThrowsError(try service.generatePairingCode(for: childId, ttlMinutes: 5)) { error in
            guard case PairingError.rateLimitExceeded = error else {
                return XCTFail("Expected rateLimitExceeded, got \(error)")
            }
        }
    }
}