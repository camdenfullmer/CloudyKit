import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(CKContainerTests.allTests),
        testCase(CKRecordTests.allTests),
        testCase(CKDatabaseTests.allTests),
        testCase(CKAssetTests.allTests),
        testCase(PredicatePlusHelpersTests.allTests),
    ]
}
#endif
