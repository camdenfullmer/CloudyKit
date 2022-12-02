//
//  CKDatabaseTests.swift
//  
//
//  Created by Camden on 12/21/20.
//

import XCTest
#if os(Linux)
import FoundationNetworking
#endif
@testable import CloudyKit

final class CKDatabaseTests: XCTestCase {
    
    var mockedSession: MockedNetworkSession? = nil
    
    override func setUp() {
        let session = MockedNetworkSession()
        session.responseHandler = { _ in
            return (Data(), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        CloudyKitConfig.environment = .development
        CloudyKitConfig.urlSession = session
        CloudyKitConfig.serverKeyID = "1234567890"
        CloudyKitConfig.serverPrivateKey = try! CKPrivateKey(data: Data.loadAsset(name: "eckey.pem"))
        self.mockedSession = session
    }
    
    func testSaveNewRecord() {
        let response = """
{
        "records": [
            {
                "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                "recordType": "Users",
                "recordChangeTag": "\(UUID().uuidString)",
                "created": {
                    "timestamp": \(Int(Date().timeIntervalSince1970 * 1000))
                },
                "fields": {
                    "firstName" : {"value" : "Mei", "type": "STRING"},
                    "lastName" : {"value" : "Chen", "type": "STRING"},
                    "width": {"value": 18},
                    "height": {"value": 24},
                    "bytes": {"value": "AAECAwQ=", "type": "BYTES"},
                    "bytesList": {"value": ["AAECAwQ="], "type": "BYTES_LIST"},
                    "double": {"value": 1.234, "type": "DOUBLE"},
                    "stringsList": {"value": ["foo", "bar"], "type": "STRING_LIST"},
                    "reference": {
                        "value": {
                            "recordName": "D27CC4CB-CC49-4710-9370-418A0E97D71C",
                            "action": "NONE"
                        }
                    },
                    "referenceList" : {
                        "value" : [ {
                            "recordName" : "D27CC4CB-CC49-4710-9370-418A0E97D71C",
                            "action" : "NONE",
                            "zoneID" : {
                                "zoneName" : "_defaultZone",
                                "ownerRecordName" : "_defaultOwner",
                                "zoneType" : "DEFAULT_ZONE"
                            }
                        }, {
                            "recordName" : "D27CC4CB-CC49-4710-9370-418A0E97D71C",
                            "action" : "NONE",
                            "zoneID" : {
                                "zoneName" : "_defaultZone",
                                "ownerRecordName" : "_defaultOwner",
                                "zoneType" : "DEFAULT_ZONE"
                            }
                        } ],
                        "type" : "REFERENCE_LIST"
                    },
                    "dateTime": { "value": 1609034460447, "type": "TIMESTAMP" }
                }
            }
        ]
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let record = CloudyKit.CKRecord(recordType: "Users")
        let reference = CKRecord.Reference(recordID: CKRecord.ID(recordName: "D27CC4CB-CC49-4710-9370-418A0E97D71C"), action: .none)
        let dateTime = Date(timeIntervalSince1970: TimeInterval(1609034460447) / 1000)
        record["firstName"] = "Mei"
        record["lastName"] = "Chen"
        record["width"] = 18
        record["height"] = 24
        let data = Data([0, 1, 2, 3, 4])
        record["bytes"] = data
        record["bytesList"] = [data]
        record["stringsList"] = ["foo", "bar"]
        record["double"] = 1.234
        record["reference"] = reference
        record["referenceList"] = [reference, reference]
        record["dateTime"] = dateTime
        XCTAssertNil(record.creationDate)
        let expectation = self.expectation(description: "completion handler called")
        database.save(record) { (record, error) in
            XCTAssertEqual("POST", self.mockedSession?.requests.first?.httpMethod)
            XCTAssertNotNil(self.mockedSession?.requests.first?.httpBody)
            XCTAssertEqual("1234567890", self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date"))
            XCTAssertNil(error)
            XCTAssertNotNil(record)
            XCTAssertEqual("Users", record?.recordType)
            XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", record?.recordID.recordName)
            XCTAssertEqual("Mei", record?["firstName"] as? String)
            XCTAssertEqual("Chen", record?["lastName"] as? String)
            XCTAssertEqual(18, record?["width"] as? Int)
            XCTAssertEqual(24, record?["height"] as? Int)
            XCTAssertEqual(Data([0, 1, 2, 3, 4]), record?["bytes"] as? Data)
            XCTAssertEqual([Data([0, 1, 2, 3, 4])], record?["bytesList"] as? [Data])
            XCTAssertEqual(["foo","bar"], record?["stringsList"] as? [String])
            XCTAssertEqual(1.234, record?["double"] as? Double)
            XCTAssertEqual(reference, record?["reference"] as? CloudyKit.CKRecord.Reference)
            XCTAssertEqual([reference, reference], (record?["referenceList"] as? [CloudyKit.CKRecord.Reference]))
            XCTAssertEqual(dateTime, record?["dateTime"] as? Date)
            XCTAssertNotNil(record?.creationDate)
            XCTAssertNotNil(record?.recordChangeTag)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testSaveNewRecordWithZeroDouble() {
        let response = """
{
        "records": [
            {
                "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                "recordType": "Users",
                "recordChangeTag": "\(UUID().uuidString)",
                "created": {
                    "timestamp": \(Int(Date().timeIntervalSince1970 * 1000))
                },
                "fields": {
                    "double": {"value": 0.0, "type": "DOUBLE"}
                }
            }
        ]
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let record = CloudyKit.CKRecord(recordType: "Users")
        record["double"] = Double(0)
        let expectation = self.expectation(description: "completion handler called")
        database.save(record) { (record, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(record)
            XCTAssertEqual(Double(0), record?["double"] as? Double)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testSaveNewRecordWithAsset() {
        let wrappingKey = UUID().uuidString
        let fileChecksum = UUID().uuidString
        let receipt = UUID().uuidString
        let referenceChecksum = UUID().uuidString
        let recordResponse = """
{
        "records": [
            {
                "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                "recordType": "Users",
                "recordChangeTag": "\(UUID().uuidString)",
                "created": {
                    "timestamp": \(Int(Date().timeIntervalSince1970 * 1000))
                },
                "fields": {
                    "profilePhoto" : {
                        "value" : {
                            "fileChecksum" : "\(fileChecksum)",
                            "downloadURL" : "https://s3.apple.com/profilePhoto/${f}",
                            "size" : 123
                        }
                    }
                }
            }
        ]
}
"""
        let assetTokenResponse = """
{
  "tokens":[{
        "recordName": "\(UUID().uuidString)",
        "fieldName": "profilePhoto",
        "url": "https://s3.apple.com/profilePhoto"
    }]
}
"""
        let assetUploadDataResponse = """
{
  "singleFile" :{
        "wrappingKey" : "\(wrappingKey)",
        "fileChecksum" : "\(fileChecksum)",
        "receipt" : "\(receipt)",
        "referenceChecksum" : "\(referenceChecksum)",
        "size" : 123
    }
}
"""
        
        mockedSession?.responseHandler = { request in
            if let url = request.url?.absoluteString {
                if url.contains("records/modify") {
                    return (recordResponse.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
                } else if url.contains("assets/upload") {
                    return (assetTokenResponse.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
                } else if url.contains("https://s3.apple.com/profilePhoto") {
                    XCTAssertNotNil(request.httpBody)
                    return (assetUploadDataResponse.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
                }
            }
            return (Data(), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 404, httpVersion: nil, headerFields: [:]), nil)
        }
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let record = CloudyKit.CKRecord(recordType: "Users")
        let asset = CloudyKit.CKAsset(fileURL: assetURL(name: "cloudkit-128x128.png")!)
        record["profilePhoto"] = asset
        XCTAssertNil(record.creationDate)
        let expectation = self.expectation(description: "completion handler called")
        database.save(record) { (record, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(record)
            XCTAssertEqual("Users", record?.recordType)
            XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", record?.recordID.recordName)
            XCTAssertNotNil(record?["profilePhoto"] as? CloudyKit.CKAsset)
            XCTAssertNotNil(record?.creationDate)
            XCTAssertNotNil(record?.recordChangeTag)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testSaveNewRecordWithAssetList() {
        let wrappingKey = UUID().uuidString
        let fileChecksum = UUID().uuidString
        let receipt = UUID().uuidString
        let referenceChecksum = UUID().uuidString
        let recordResponse = """
{
        "records": [
            {
                "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                "recordType": "Users",
                "recordChangeTag": "\(UUID().uuidString)",
                "created": {
                    "timestamp": \(Int(Date().timeIntervalSince1970 * 1000))
                },
                "fields": {
                    "profilePhotos" : {
                        "value" : [{
                            "fileChecksum" : "\(fileChecksum)",
                            "downloadURL" : "https://s3.apple.com/profilePhoto/${f}",
                            "size" : 123
                        }]
                    }
                }
            }
        ]
}
"""
        let assetTokenResponse = """
{
  "tokens":[{
        "recordName": "\(UUID().uuidString)",
        "fieldName": "profilePhotos",
        "url": "https://s3.apple.com/profilePhoto"
    }]
}
"""
        let assetUploadDataResponse = """
{
  "singleFile" :{
        "wrappingKey" : "\(wrappingKey)",
        "fileChecksum" : "\(fileChecksum)",
        "receipt" : "\(receipt)",
        "referenceChecksum" : "\(referenceChecksum)",
        "size" : 123
    }
}
"""
        
        mockedSession?.responseHandler = { request in
            if let url = request.url?.absoluteString {
                if url.contains("records/modify") {
                    return (recordResponse.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
                } else if url.contains("assets/upload") {
                    return (assetTokenResponse.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
                } else if url.contains("https://s3.apple.com/profilePhoto") {
                    XCTAssertNotNil(request.httpBody)
                    return (assetUploadDataResponse.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
                }
            }
            return (Data(), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 404, httpVersion: nil, headerFields: [:]), nil)
        }
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let record = CloudyKit.CKRecord(recordType: "Users")
        let asset = CloudyKit.CKAsset(fileURL: assetURL(name: "cloudkit-128x128.png")!)
        record["profilePhotos"] = [asset]
        XCTAssertNil(record.creationDate)
        let expectation = self.expectation(description: "completion handler called")
        database.save(record) { (record, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(record)
            XCTAssertEqual("Users", record?.recordType)
            XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", record?.recordID.recordName)
            XCTAssertNotNil(record?["profilePhotos"] as? [CloudyKit.CKAsset])
            XCTAssertEqual(1, (record?["profilePhotos"] as? [CloudyKit.CKAsset])?.count ?? 0)
            XCTAssertNotNil(record?.creationDate)
            XCTAssertNotNil(record?.recordChangeTag)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testSaveNewRecordWithEmptyStringArray() {
        let response = """
{
        "records": [
            {
                "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                "recordType": "Users",
                "recordChangeTag": "\(UUID().uuidString)",
                "created": {
                    "timestamp": \(Int(Date().timeIntervalSince1970 * 1000))
                },
                "fields": {
                    "stringsList": {"value": [], "type": "STRING_LIST"},
                }
            }
        ]
}
"""
        let noAssetUploadExpectation = self.expectation(description: "asset upload was not triggered")
        mockedSession?.responseHandler = { request in
            if let url = request.url?.absoluteString {
                if url.contains("assets/upload") {
                    noAssetUploadExpectation.fulfill()
                }
            }
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let record = CloudyKit.CKRecord(recordType: "Users")
        record["stringsList"] = []
        XCTAssertNil(record.creationDate)
        let expectation = self.expectation(description: "completion handler called")
        noAssetUploadExpectation.isInverted = true
        database.save(record) { (record, error) in
            XCTAssertEqual("POST", self.mockedSession?.requests.first?.httpMethod)
            XCTAssertNotNil(self.mockedSession?.requests.first?.httpBody)
            XCTAssertEqual("1234567890", self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date"))
            XCTAssertNil(error)
            XCTAssertNotNil(record)
            XCTAssertEqual("Users", record?.recordType)
            XCTAssertEqual([], record?["stringsList"] as? [String])
            XCTAssertNotNil(record?.creationDate)
            XCTAssertNotNil(record?.recordChangeTag)
            expectation.fulfill()
        }
        self.wait(for: [expectation, noAssetUploadExpectation], timeout: 1)
    }
    
    func testFetchRecord() {
        let response = """
{
        "records": [
            {
                "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                "recordType": "Users",
                "recordChangeTag": "\(UUID().uuidString)",
                "created": {
                    "timestamp": \(Int(Date().timeIntervalSince1970 * 1000))
                },
                "fields": {
                    "firstName" : {"value" : "Mei", "type": "STRING"},
                    "lastName" : {"value" : "Chen", "type": "STRING"},
                    "width": {"value": 18},
                    "height": {"value": 24}
                }
            }
        ]
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let recordID = CKRecord.ID(recordName: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let expectation = self.expectation(description: "completion handler called")
        database.fetch(withRecordID: recordID) { (record, error) in
            XCTAssertEqual("POST", self.mockedSession?.requests.first?.httpMethod)
            XCTAssertNotNil(self.mockedSession?.requests.first?.httpBody)
            XCTAssertEqual("1234567890", self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date"))
            XCTAssertNil(error)
            XCTAssertNotNil(record)
            XCTAssertEqual("Users", record?.recordType)
            XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", record?.recordID.recordName)
            XCTAssertEqual("Mei", record?["firstName"] as? String)
            XCTAssertEqual("Chen", record?["lastName"] as? String)
            XCTAssertEqual(18, record?["width"] as? Int)
            XCTAssertEqual(24, record?["height"] as? Int)
            XCTAssertNotNil(record?.creationDate)
            XCTAssertNotNil(record?.recordChangeTag)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testQueryRecords() {
        let response = """
{
        "records": [
            {
                "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                "recordType": "Users",
                "recordChangeTag": "\(UUID().uuidString)",
                "created": {
                    "timestamp": \(Int(Date().timeIntervalSince1970 * 1000))
                },
                "fields": {
                    "firstName" : {"value" : "Mei", "type": "STRING"},
                    "lastName" : {"value" : "Chen", "type": "STRING"},
                    "width": {"value": 18},
                    "height": {"value": 24}
                }
            }
        ]
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }

        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let expectation = self.expectation(description: "completion handler called")
        let query = CKQuery(recordType: "Users", predicate: Predicate(value: true))
        query.sortDescriptors = [SortDescriptor(key: "firstName", ascending: false)]
        database.perform(query, inZoneWith: nil) { (records, error) in
            XCTAssertEqual("POST", self.mockedSession?.requests.first?.httpMethod)
            XCTAssertNotNil(self.mockedSession?.requests.first?.httpBody)
            XCTAssertEqual("1234567890", self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date"))
            XCTAssertNil(error)
            XCTAssertNotNil(records)
            XCTAssertEqual("Users", records?.first?.recordType)
            XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", records?.first?.recordID.recordName)
            XCTAssertEqual("Mei", records?.first?["firstName"] as? String)
            XCTAssertEqual("Chen", records?.first?["lastName"] as? String)
            XCTAssertEqual(18, records?.first?["width"] as? Int)
            XCTAssertEqual(24, records?.first?["height"] as? Int)
            XCTAssertNotNil(records?.first?.creationDate)
            XCTAssertNotNil(records?.first?.recordChangeTag)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testDeleteRecord() {
        let response = """
{
        "records": [
            {
                "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
            }
        ]
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let recordID = CKRecord.ID(recordName: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let expectation = self.expectation(description: "completion handler called")
        database.delete(withRecordID: recordID) { (recordID, error) in
            XCTAssertEqual("POST", self.mockedSession?.requests.first?.httpMethod)
            XCTAssertNotNil(self.mockedSession?.requests.first?.httpBody)
            XCTAssertEqual("1234567890", self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1"))
            XCTAssertNotNil(self.mockedSession?.requests.first?.value(forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date"))
            XCTAssertNil(error)
            XCTAssertNotNil(recordID)
            XCTAssertEqual("E621E1F8-C36C-495A-93FC-0C247A3E6E5F", recordID?.recordName)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testNoRecordChangeTagError() {
        let response = """
{
    "uuid" : "\(UUID().uuidString)",
    "serverErrorCode" : "BAD_REQUEST",
    "reason" : "BadRequestException: missing required field 'recordChangeTag'"
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 400, httpVersion: nil, headerFields: [:]), nil)
        }
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let recordID = CKRecord.ID(recordName: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let expectation = self.expectation(description: "completion handler called")
        database.fetch(withRecordID: recordID) { (record, error) in
            XCTAssertNil(record)
            XCTAssertNotNil(error)
            XCTAssertEqual(CloudyKit.CKError.Code.invalidArguments.rawValue, (error as? CloudyKit.CKError)?.errorCode)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testCouldNotDecodeError() {
        let response = """
{
    "uuid" : "\(UUID().uuidString)",
    "serverErrorCode" : "BAD_REQUEST",
    "reason" : "could not decode asset object"
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let recordID = CKRecord.ID(recordName: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let expectation = self.expectation(description: "completion handler called")
        database.fetch(withRecordID: recordID) { (record, error) in
            XCTAssertNil(record)
            XCTAssertNotNil(error)
            XCTAssertEqual(CloudyKit.CKError.Code.invalidArguments.rawValue, (error as? CloudyKit.CKError)?.errorCode)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testNotFoundError() {
        let response = """
{
    "records": [{
        "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
        "serverErrorCode" : "NOT_FOUND",
        "reason" : "Record not found"
    }]
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let recordID = CKRecord.ID(recordName: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let expectation = self.expectation(description: "completion handler called")
        database.fetch(withRecordID: recordID) { (record, error) in
            XCTAssertNil(record)
            XCTAssertNotNil(error)
            XCTAssertEqual(CloudyKit.CKError.Code.unknownItem.rawValue, (error as? CloudyKit.CKError)?.errorCode)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testQueriedTypeIsNotIndexableError() {
        let response = """
{
    "uuid" : "\(UUID().uuidString)",
    "serverErrorCode" : "BAD_REQUEST",
    "reason" : "Queried type is not marked indexable"
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let recordID = CKRecord.ID(recordName: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let expectation = self.expectation(description: "completion handler called")
        database.fetch(withRecordID: recordID) { (record, error) in
            XCTAssertNil(record)
            XCTAssertNotNil(error)
            XCTAssertEqual(CloudyKit.CKError.Code.invalidArguments.rawValue, (error as? CloudyKit.CKError)?.errorCode)
            XCTAssertEqual("Type is not marked indexable", error?.localizedDescription)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testQueriedFieldIsNotQueryableError() {
        let response = """
{
    "uuid" : "\(UUID().uuidString)",
    "serverErrorCode" : "BAD_REQUEST",
    "reason" : "Field 'productID' is not marked queryable"
}
"""
        mockedSession?.responseHandler = { _ in
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let recordID = CKRecord.ID(recordName: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let expectation = self.expectation(description: "completion handler called")
        database.fetch(withRecordID: recordID) { (record, error) in
            XCTAssertNil(record)
            XCTAssertNotNil(error)
            XCTAssertEqual(CloudyKit.CKError.Code.invalidArguments.rawValue, (error as? CloudyKit.CKError)?.errorCode)
            XCTAssertEqual("Field 'productID' is not marked queryable", error?.localizedDescription)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }
    
    func testEnvironment() {
        let response = """
{
        "records": [
            {
                "recordName": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
                "recordType": "Users",
                "recordChangeTag": "\(UUID().uuidString)",
                "created": {
                    "timestamp": \(Int(Date().timeIntervalSince1970 * 1000))
                },
                "fields": {
                    "firstName" : {"value" : "Mei"},
                    "lastName" : {"value" : "Chen"},
                    "width": {"value": 18},
                    "height": {"value": 24}
                }
            }
        ]
}
"""
        CloudyKitConfig.environment = .production
        mockedSession?.responseHandler = { sessionResponse in
            if let url = sessionResponse.url {
                XCTAssertTrue(url.absoluteString.contains("production"))
                XCTAssertTrue(url.absoluteString.contains("public"))
                XCTAssertTrue(url.absoluteString.contains("iCloud.com.example.myexampleapp"))
            } else {
                XCTFail("session response url is nil")
            }
            return (response.data(using: .utf8), HTTPURLResponse(url: URL(string: "https://apple.com")!, statusCode: 200, httpVersion: nil, headerFields: [:]), nil)
        }
        
        let container = CKContainer(identifier: "iCloud.com.example.myexampleapp")
        let database = container.publicDatabase
        let recordID = CKRecord.ID(recordName: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let expectation = self.expectation(description: "completion handler called")
        database.fetch(withRecordID: recordID) { (record, error) in
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 1)
    }

    static var allTests = [
        ("testSaveNewRecord", testSaveNewRecord),
        ("testFetchRecord", testFetchRecord),
        ("testQueryRecords", testQueryRecords),
        ("testNoRecordChangeTagError", testNoRecordChangeTagError),
        ("testDeleteRecord", testDeleteRecord),
        ("testEnvironment", testEnvironment),
    ]
}

