import XCTest
@testable import Core

@MainActor
final class CloudKitDebuggerTests: XCTestCase {
    private var debugger: CloudKitDebugger!
    
    override func setUp() {
        super.setUp()
        debugger = CloudKitDebugger()
    }
    
    override func tearDown() {
        debugger = nil
        super.tearDown()
    }
    
    func testStartAndStopMonitoring() {
        XCTAssertFalse(debugger.isMonitoring)
        
        debugger.startMonitoring()
        XCTAssertTrue(debugger.isMonitoring)
        
        debugger.stopMonitoring()
        XCTAssertFalse(debugger.isMonitoring)
    }
    
    func testLogOperation() async {
        debugger.startMonitoring()
        
        XCTAssertEqual(debugger.debugLogs.count, 1) // "Monitoring Started" log
        
        debugger.logOperation("Test Operation", details: "Test details")
        XCTAssertEqual(debugger.debugLogs.count, 2)
        
        let lastLog = debugger.debugLogs.last!
        XCTAssertEqual(lastLog.operation, "Test Operation")
        XCTAssertEqual(lastLog.details, "Test details")
        XCTAssertNil(lastLog.error)
    }
    
    func testLogOperationWithError() async {
        debugger.startMonitoring()
        
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        debugger.logOperation("Failed Operation", details: "Test failure", error: testError)
        
        let lastLog = debugger.debugLogs.last!
        XCTAssertEqual(lastLog.operation, "Failed Operation")
        XCTAssertEqual(lastLog.details, "Test failure")
        XCTAssertEqual(lastLog.error, "Test error")
        XCTAssertTrue(lastLog.hasError)
    }
    
    func testLogChildOperations() async {
        debugger.startMonitoring()
        
        debugger.logChildAdded(childId: "child-123", familyId: "family-456")
        let addLog = debugger.debugLogs.last!
        XCTAssertEqual(addLog.operation, "Add Child")
        XCTAssertEqual(addLog.details, "Child: child-123, Family: family-456")
        
        debugger.logChildRemoved(childId: "child-123", familyId: "family-456")
        let removeLog = debugger.debugLogs.last!
        XCTAssertEqual(removeLog.operation, "Remove Child")
        XCTAssertEqual(removeLog.details, "Child: child-123, Family: family-456")
        
        debugger.logChildrenFetched(familyId: "family-456", count: 3)
        let fetchLog = debugger.debugLogs.last!
        XCTAssertEqual(fetchLog.operation, "Fetch Children")
        XCTAssertEqual(fetchLog.details, "Family: family-456, Count: 3")
    }
    
    func testClearLogs() async {
        debugger.startMonitoring()
        
        debugger.logOperation("Test 1")
        debugger.logOperation("Test 2")
        debugger.logOperation("Test 3")
        
        XCTAssertEqual(debugger.debugLogs.count, 4) // Including "Monitoring Started"
        
        debugger.clearLogs()
        XCTAssertEqual(debugger.debugLogs.count, 0)
    }
    
    func testLogWhenNotMonitoring() async {
        XCTAssertFalse(debugger.isMonitoring)
        
        debugger.logOperation("Test Operation")
        XCTAssertEqual(debugger.debugLogs.count, 0)
        
        debugger.startMonitoring()
        debugger.logOperation("Test Operation")
        XCTAssertEqual(debugger.debugLogs.count, 2) // "Monitoring Started" + "Test Operation"
    }
}