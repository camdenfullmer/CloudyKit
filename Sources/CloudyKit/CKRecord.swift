//
//  CKRecord.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation

public class CKRecord {
    
    public typealias RecordType = String
    
    public class ID {
        public let recordName: String
        public init(recordName: String = UUID().uuidString) {
            self.recordName = recordName
        }
    }
    
    public let recordID: ID
    public let recordType: RecordType

    internal var fields: [String:Any]
    
    public init(recordType: CKRecord.RecordType, recordID: CKRecord.ID = CKRecord.ID()) {
        self.recordType = recordType
        self.recordID = recordID
        self.fields = [:]
    }
    
    public subscript(string: String) -> Any? {
        get {
            return self.fields[string]
        }
        set(newValue) {
            self.fields[string] = newValue
        }
    }
    
}
