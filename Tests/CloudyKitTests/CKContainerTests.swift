//
//  CKContainerTests.swift
//  
//
//  Created by Camden on 12/21/20.
//

import XCTest
import CloudyKit

final class CKContainerTests: XCTestCase {
    
    func testInit() {
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        XCTAssertEqual("iCloud.com.example.myexampleapp", container.containerIdentifier)
        XCTAssertEqual(CKDatabase.Scope.public, container.publicDatabase.databaseScope)
    }

    static var allTests = [
        ("testInit", testInit),
    ]
}

