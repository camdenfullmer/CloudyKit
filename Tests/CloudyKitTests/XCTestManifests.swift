import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CKContainerTests.allTests),
        testCase(CKRecordTests.allTests),
        testCase(CKDatabaseTests.allTests),
    ]
}
#endif
