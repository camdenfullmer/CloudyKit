//
//  CKModifyRecordRequest.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation

struct CKResponseCreated: Codable {
    let timestamp: Int
}

enum CKValue: Codable {
    case string(String)
    case number(Int)
    
    init(from decoder: Decoder) throws {
        // TODO: This is not going to work for references or booleans.
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unable to decode value from container: \(container)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        }
    }
}

struct CKRecordFieldValue: Codable {
    let value: CKValue
    let type: String?    
    internal init(value: CKValue, type: String?) {
        self.value = value
        self.type = type
    }
}

struct CKRecordDictionary: Codable {
    let recordName: String
    let recordType: String?
    let recordChangeTag: String?
    let fields: [String:CKRecordFieldValue]?
    let created: CKResponseCreated?
}

struct CKRecordOperation: Encodable {
    enum OperationType: String, Encodable {
        case create = "create"
        case update = "update"
        case forceUpdate = "forceUpdate"
        case replace = "replace"
        case forceReplace = "forceReplace"
        case delete = "delete"
        case forceDelete = "forceDelete"
    }
    
    let operationType: OperationType
    let desiredKeys: [String]?
    let record: CKRecordDictionary
}

struct CKModifyRecordRequest: Encodable {
    let operations: [CKRecordOperation]
}

struct CKModifyRecordResponse: Decodable {
    let records: [CKRecordDictionary]
}
