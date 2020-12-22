//
//  CKRecordTests.swift
//
//
//  Created by Camden on 12/21/20.
//

import XCTest
import CloudyKit

final class CKRecordTests: XCTestCase {
    
    func testInit() {
        let record = CloudyKit.CKRecord(recordType: "Users")
        XCTAssertEqual("Users", record.recordType)
    }

    static var allTests = [
        ("testInit", testInit),
    ]
}

