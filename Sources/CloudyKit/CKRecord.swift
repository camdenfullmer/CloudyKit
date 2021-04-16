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
    
    public class Reference: NSObject {
        public enum Action: Int {
            case none = 0
            case deleteSelf = 1
            
            internal init(string: String) {
                switch string {
                case "DELETE_SELF": self = .deleteSelf
                default: self = .none
                }
            }
            
            internal var stringValue: String {
                switch self {
                case .deleteSelf: return "DELETE_SELF"
                case .none: return "NONE"
                }
            }
        }
        
        public let recordID: ID
        public let action: Action
        
        public convenience init(record: CKRecord, action: CKRecord.Reference.Action) {
            self.init(recordID: record.recordID, action: action)
        }
        
        public init(recordID: CKRecord.ID, action: CKRecord.Reference.Action) {
            self.recordID = recordID
            self.action = action
        }
        
        public override var description: String {
            return withUnsafePointer(to: self) { (pointer) -> String in
                return "<CKReference: \(pointer.debugDescription); recordID=\(self.recordID)>"
            }
        }
        
        public override func isEqual(_ object: Any?) -> Bool {
            guard let reference = object as? CKRecord.Reference else {
                return false
            }
            return self.recordID == reference.recordID && self.action == reference.action
        }
    }
    
    public let recordID: ID
    public let recordType: RecordType
    public internal(set) var recordChangeTag: String?
    public internal(set) var creationDate: Date?

    internal var fields: [String:Any]
    
    public init(recordType: CKRecord.RecordType, recordID: CKRecord.ID = CKRecord.ID()) {
        self.recordType = recordType
        self.recordID = recordID
        self.fields = [:]
        self.recordChangeTag = nil
        self.creationDate = nil
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

extension CKRecord.ID: Equatable {
    public static func == (lhs: CKRecord.ID, rhs: CKRecord.ID) -> Bool {
        return lhs.recordName == rhs.recordName
    }
}

extension CKRecord.ID: CustomStringConvertible {
    
    public var description: String {
        return withUnsafePointer(to: self) { (pointer) -> String in
            return "<CKRecordID: \(pointer.debugDescription); recordName=\(self.recordName), zoneID=_defaultZone:__defaultOwner__>"
        }
        
    }
}
