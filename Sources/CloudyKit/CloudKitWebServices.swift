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
    let receipt: String
    let downloadURL: String?
}

enum CKWSValue: Codable {
    case string(String)
    case number(Int)
    case asset(CKWSAssetDictionary)
    
    init(from decoder: Decoder) throws {
        // TODO: This is not going to work for references or booleans.
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(value)
        } else if let value = try? container.decode(CKWSAssetDictionary.self) {
            self = .asset(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unable to decode value from container: \(container)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .number(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .asset(_):
            var container = encoder.unkeyedContainer()
            let assetDictionary = CKWSAssetDictionary(fileChecksum: "",
                                                      size: 0,
                                                      referenceChecksum: nil,
                                                      wrappingKey: nil,
                                                      receipt: "",
                                                      downloadURL: nil)
            try container.encode(assetDictionary)
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
