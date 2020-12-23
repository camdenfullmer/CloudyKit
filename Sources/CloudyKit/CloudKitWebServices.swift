//
//  CloudKitWebServices.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation

struct CKWSErrorResponse: Decodable {
    let uuid: String
    let serverErrorCode: String
    let reason: String
}

struct CKWSResponseCreated: Codable {
    let timestamp: Int
}

enum CKWSValue: Codable {
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

struct CKWSRecordFieldValue: Codable {
    let value: CKWSValue
    let type: String?    
    internal init(value: CKWSValue, type: String?) {
        self.value = value
        self.type = type
    }
}

struct CKWSRecordDictionary: Codable {
    let recordName: String
    let recordType: String?
    let recordChangeTag: String?
    let fields: [String:CKWSRecordFieldValue]?
    let created: CKWSResponseCreated?
}

struct CKWSRecordOperation: Encodable {
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
    let record: CKWSRecordDictionary
}

struct CKWSRecordResponse: Decodable {
    let records: [CKWSRecordDictionary]
}

struct CKWSModifyRecordRequest: Encodable {
    let operations: [CKWSRecordOperation]
}

struct CKWSLookupRecordDictionary: Encodable {
    let recordName: String
}

struct CKWSFetchRecordRequest: Encodable {
    let records: [CKWSLookupRecordDictionary]
}
