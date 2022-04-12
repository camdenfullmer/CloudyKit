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

extension CKWSErrorResponse {
    
    var ckError: CKError {
        if self.serverErrorCode == "BAD_REQUEST" {
            var userInfo: [String:Any] = [:]
            if reason == "Queried type is not marked indexable" {
                userInfo[NSLocalizedDescriptionKey] = "Type is not marked indexable"
            } else if reason.contains("is not marked queryable") && reason.hasPrefix("Field") {
                userInfo[NSLocalizedDescriptionKey] = reason
            }
            return CKError(code: .invalidArguments, userInfo: userInfo)
        } else {
            return CKError(code: .internalError, userInfo: [:])
        }
    }
    
}

struct CKWSResponseCreated: Codable {
    let timestamp: Int
}

struct CKWSAssetDictionary: Codable {
    let fileChecksum: String
    let size: Int
    let referenceChecksum: String?
    let wrappingKey: String?
    let receipt: String?
    let downloadURL: String?
}

extension CKWSAssetDictionary: Equatable {}

struct CKWSReferenceDictionary: Codable {
    let recordName: String
    let action: String
}

extension CKWSReferenceDictionary: Equatable {}

enum CKWSValue {
    case string(String)
    case stringList(Array<String>)
    case number(Int)
    case asset(CKWSAssetDictionary)
    case assetList(Array<CKWSAssetDictionary>)
    case bytes(Data)
    case bytesList(Array<Data>)
    case double(Double)
    case reference(CKWSReferenceDictionary)
    case referenceList(Array<CKWSReferenceDictionary>)
    case dateTime(Int)
}

extension CKWSValue: Equatable {
    static func == (lhs: CKWSValue, rhs: CKWSValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let ls), .string(let rs)):
            return ls == rs
        case (.stringList(let ls), .stringList(let rs)):
            return ls == rs
        case (.number(let ls), .number(let rs)):
            return ls == rs
        case (.asset(let ls), .asset(let rs)):
            return ls == rs
        case (.assetList(let ls), .assetList(let rs)):
            return ls == rs
        case (.bytes(let ls), .bytes(let rs)):
            return ls == rs
        case (.bytesList(let ls), .bytesList(let rs)):
            return ls == rs
        case (.double(let ls), .double(let rs)):
            return ls == rs
        case (.reference(let ls), .reference(let rs)):
            return ls == rs
        case (.dateTime(let ls), .dateTime(let rs)):
            return ls == rs
        default: return false
        }
    }
}

struct CKWSRecordFieldValue: Codable {
    let value: CKWSValue
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case value = "value"
        case type = "type"
    }
    
    internal init(value: CKWSValue, type: String?) {
        self.value = value
        self.type = type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        if let value = try? container.decode(String.self, forKey: .value), self.type == "BYTES" {
            let data = Data(base64Encoded: value) ?? Data()
           self.value = .bytes(data)
        } else if let value = try? container.decode(Int.self, forKey: .value), self.type == "TIMESTAMP" {
            self.value = .dateTime(value)
        } else if let value = try? container.decode(Double.self, forKey: .value), self.type == "DOUBLE" {
            self.value = .double(value)
        } else if let value = try? container.decode([String].self, forKey: .value), self.type == "BYTES_LIST" {
            let datas = value.compactMap({ Data(base64Encoded: $0) })
            self.value = .bytesList(datas)
        } else if let value = try? container.decode([String].self, forKey: .value), self.type == "STRING_LIST" {
            self.value = .stringList(value)
        } else if let value = try? container.decode(String.self, forKey: .value), self.type == "STRING" {
            self.value = .string(value)
        } else if let value = try? container.decode(Int.self, forKey: .value) {
            self.value = .number(value)
        } else if let value = try? container.decode(CKWSAssetDictionary.self, forKey: .value) {
            self.value = .asset(value)
        } else if let value = try? container.decode([CKWSAssetDictionary].self, forKey: .value) {
            self.value = .assetList(value)
        } else if let value = try? container.decode(CKWSReferenceDictionary.self, forKey: .value) {
            self.value = .reference(value)
        } else if let value = try? container.decode([CKWSReferenceDictionary].self, forKey: .value) {
            self.value = .referenceList(value)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "unable to decode value from container: \(container)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self.value {
        case .string(let value):
            try container.encode(value, forKey: .value)
        case .number(let value):
            try container.encode(value, forKey: .value)
        case .asset(let value):
            try container.encode(value, forKey: .value)
        case .assetList(let value):
            try container.encode(value, forKey: .value)
        case .bytes(let value):
            try container.encode(value.base64EncodedString(), forKey: .value)
        case .bytesList(let value):
            try container.encode(value.compactMap { $0.base64EncodedString() }, forKey: .value)
        case .double(let value):
            try container.encode(value, forKey: .value)
        case .reference(let value):
            try container.encode(value, forKey: .value)
        case .dateTime(let value):
            try container.encode(value, forKey: .value)
        case .stringList(let value):
            try container.encode(value, forKey: .value)
        case .referenceList(let value):
            try container.encode(value, forKey: .value)
        }
        try container.encodeIfPresent(self.type, forKey: .type)
    }
}

extension CKWSRecordFieldValue: Equatable {}

struct CKWSRecordDictionary: Codable {
    let recordName: String
    let recordType: String?
    let recordChangeTag: String?
    let fields: [String:CKWSRecordFieldValue]?
    let created: CKWSResponseCreated?
    let serverErrorCode: String?
    let reason: String?
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

struct CKWSTokenResponseDictionary: Decodable {
    let recordName: String
    let fieldName: String
    let url: String
}

struct CKWSTokenResponse: Decodable {
    let tokens: [CKWSTokenResponseDictionary]
}

struct CKWSAssetFieldDictionary: Encodable {
    let recordName: String
    let recordType: String
    let fieldName: String
}

struct CKWSAssetTokenRequest: Encodable {
    let tokens: [CKWSAssetFieldDictionary]
}

struct CKWSAssetUploadResponse: Decodable {
    let singleFile: CKWSAssetDictionary
}

struct CKWSZoneIDDictionary: Encodable {
    let zoneName: String
    let ownerName: String
}

struct CKWSFilterDictionary: Encodable {
    
    enum Comparator: String, Encodable {
        case equals = "EQUALS"
        case notEquals = "NOT_EQUALS"
        case lessThan = "LESS_THAN"
        case lessThanOrEquals = "LESS_THAN_OR_EQUALS"
        case greaterThan = "GREATER_THAN"
        case greaterThanOrEquals = "GREATER_THAN_OR_EQUALS"
        case near = "NEAR"
        case containsAllTokens = "CONTAINS_ALL_TOKENS"
        case `in` = "IN"
        case notIn = "NOT_IN"
        case containsAnyTokens = "CONTAINS_ANY_TOKENS"
        case listContains = "LIST_CONTAINS"
        case notListContains = "NOT_LIST_CONTAINS"
        case notListContainsAny = "NOT_LIST_CONTAINS_ANY"
        case beginsWith = "BEGINS_WITH"
        case notBeginsWith = "NOT_BEGINS_WITH"
        case listMemberBeginsWith = "LIST_MEMBER_BEGINS_WITH"
        case notListMemberBeginsWith = "NOT_LIST_MEMBER_BEGINS_WITH"
        case listContainsAll = "LIST_CONTAINS_ALL"
        case notListContainsAll = "NOT_LIST_CONTAINS_ALL"
    }
    
    let comparator: Comparator
    let fieldName: String
    let fieldValue: CKWSRecordFieldValue
}

extension CKWSFilterDictionary: Equatable {
    static func == (lhs: CKWSFilterDictionary, rhs: CKWSFilterDictionary) -> Bool {
        return lhs.comparator == rhs.comparator && lhs.fieldValue == rhs.fieldValue && lhs.fieldName == rhs.fieldName
    }
}

struct CKWSSortDescriptorDictionary: Encodable {
    let fieldName: String?
    let ascending: Bool
}

struct CKWSQueryDictionary: Encodable {
    let recordType: String
    let filterBy: [CKWSFilterDictionary]?
    let sortBy: [CKWSSortDescriptorDictionary]?
}

struct CKWSQueryRequest: Encodable {
    let zoneID: CKWSZoneIDDictionary?
    let resultsLimit: Int?
    let query: CKWSQueryDictionary
}
