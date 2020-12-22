//
//  CKDatabaseTests.swift
//  
//
//  Created by Camden on 12/21/20.
//

import XCTest
@testable import CloudyKit

final class CKDatabaseTests: XCTestCase {
    
    var mockedSession: MockedNetworkSession? = nil
    
    override func setUp() {
        let session = MockedNetworkSession()
        CloudyKitConfig.urlSession = session
        self.mockedSession = session
    }
    
    func testSave() {
        self.mockedSession?.mockedResponse = HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:])
        self.mockedSession?.mockedData = #"{"records":[{"recordName":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","recordType":"Users","recordChangeTag":"\#(UUID().uuidString)"}]}"#.data(using: .utf8)
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let record = CloudyKit.CKRecord(recordType: "Users")
        let expectation = self.expectation(description: "completion handler called")
        database.save(record) { (record, error) in
            XCTAssertEqual("POST", self.mockedSession?.request?.httpMethod)
            XCTAssertNil(error)
            XCTAssertNotNil(record)
            XCTAssertEqual("Users", record?.recordType)
            XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", record?.recordID.recordName)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }

    static var allTests = [
        ("testSave", testSave),
    ]
}

