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
            return CKError(code: .invalidArguments)
        } else {
            return CKError(code: .internalError)
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

enum CKWSValue {
    case string(String)
    case number(Int)
    case asset(CKWSAssetDictionary)
    case assetList(Array<CKWSAssetDictionary>)
    case bytes(Data)
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
        if let value = try? container.decode(String.self, forKey: .value), let data = Data(base64Encoded: value), self.type == "BYTES" {
           self.value = .bytes(data) // TODO: Support needs to be added to check the value type before doing this.
        } else if let value = try? container.decode(String.self, forKey: .value) {
            self.value = .string(value)
        } else if let value = try? container.decode(Int.self, forKey: .value) {
            self.value = .number(value)
        } else if let value = try? container.decode(CKWSAssetDictionary.self, forKey: .value) {
            self.value = .asset(value)
        } else if let value = try? container.decode([CKWSAssetDictionary].self, forKey: .value) {
            self.value = .assetList(value)
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
        }
        try container.encodeIfPresent(self.type, forKey: .type)
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
