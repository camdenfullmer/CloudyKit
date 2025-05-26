//
//  URLRequest+Helpers.swift
//  CloudyKit
//
//  Created by Camden on 5/26/25.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLRequest {
    
    static internal func saveRequest(database: CKDatabase, environment: CloudyKitConfig.Environment, record: CKRecord, assetUploadResponses: [(String, CKWSAssetUploadResponse)] = []) throws -> URLRequest {
        let now = Date()
        let path = "/database/1/\(database.containerIdentifier)/\(environment.rawValue)/\(database.databaseScope.description)/records/modify"
        var request = URLRequest(url: URL(string: "\(CloudyKitConfig.host)\(path)")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(CloudyKitConfig.serverKeyID, forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID")
        request.addValue(CloudyKitConfig.dateFormatter.string(from: now), forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date")
        
        var fields: [String:CKWSRecordFieldValue] = [:]
        for (fieldName, value) in record.fields {
            switch value {
            case let value as Int:
                fields[fieldName] = CKWSRecordFieldValue(value: .number(value), type: nil)
            case let value as String:
                fields[fieldName] = CKWSRecordFieldValue(value: .string(value), type: nil)
            case let value as Array<String>:
                fields[fieldName] = CKWSRecordFieldValue(value: .stringList(value), type: nil)
            case _ as CKAsset:
                guard let dictionary = assetUploadResponses.first(where: { $0.0 == fieldName })?.1.singleFile else {
                    if CloudyKitConfig.debug {
                        print("unable to locate asset upload response for \"\(fieldName)\"")
                    }
                    continue
                }
                fields[fieldName] = CKWSRecordFieldValue(value: .asset(dictionary), type: nil)
            case _ as Array<CKAsset>:
                let dictionaries = assetUploadResponses.filter({ $0.0 == fieldName })
                    .map { $0.1.singleFile }
                fields[fieldName] = CKWSRecordFieldValue(value: .assetList(dictionaries), type: nil)
            case let value as Data:
                fields[fieldName] = CKWSRecordFieldValue(value: .bytes(value), type: nil)
            case let value as Array<Data>:
                fields[fieldName] = CKWSRecordFieldValue(value: .bytesList(value), type: nil)
            case let value as Date:
                fields[fieldName] = CKWSRecordFieldValue(value: .dateTime(Int(value.timeIntervalSince1970 * 1000)), type: nil)
            case let value as Double:
                fields[fieldName] = CKWSRecordFieldValue(value: .double(value), type: nil)
            case let value as CKRecord.Reference:
                let dict = CKWSReferenceDictionary(recordName: value.recordID.recordName, action: value.action.stringValue)
                fields[fieldName] = CKWSRecordFieldValue(value: .reference(dict), type: nil)
            case let value as Array<CKRecord.Reference>:
                let dictionaries = value.map { CKWSReferenceDictionary(recordName: $0.recordID.recordName, action: $0.action.stringValue) }
                fields[fieldName] = CKWSRecordFieldValue(value: .referenceList(dictionaries), type: nil)
            default:
                fatalError("unable to handle \(value) of type \(type(of: value))")
            }
        }
        let recordDictionary = CKWSRecordDictionary(recordName: record.recordID.recordName,
                                                    recordType: record.recordType,
                                                    recordChangeTag: record.recordChangeTag,
                                                    fields: fields,
                                                    created: nil,
                                                    serverErrorCode: nil,
                                                    reason: nil)
        let operationType: CKWSRecordOperation.OperationType = record.creationDate == nil ? .create : .update
        let operation = CKWSRecordOperation(operationType: operationType,
                                            desiredKeys: nil,
                                            record: recordDictionary)
        let modifyRequest = CKWSModifyRecordRequest(operations: [operation])
        let data = try CloudyKitConfig.encoder.encode(modifyRequest)
        if let privateKey = CloudyKitConfig.serverPrivateKey {
            let signature = CKRequestSignature(data: data, date: now, path: path, privateKey: privateKey)
            let signatureValue = try signature.sign()
            request.addValue(signatureValue, forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1")
            request.httpBody = data
        }
        return request
    }
    
    static internal func queryRequest(database: CKDatabase, environment: CloudyKitConfig.Environment, query: CKQuery, zoneID: CKRecordZone.ID?) -> URLRequest {
        let now = Date()
        let path = "/database/1/\(database.containerIdentifier)/\(environment.rawValue)/\(database.databaseScope.description)/records/query"
        var request = URLRequest(url: URL(string: "\(CloudyKitConfig.host)\(path)")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(CloudyKitConfig.serverKeyID, forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID")
        request.addValue(CloudyKitConfig.dateFormatter.string(from: now), forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date")
        var zoneIDDict: CKWSZoneIDDictionary? = nil
        if let zoneID = zoneID {
            zoneIDDict = CKWSZoneIDDictionary(zoneName: zoneID.zoneName, ownerName: zoneID.ownerName)
        }
        // TODO: Support results limit.
        let filterBy = query.predicate.filterBy
        let sortBy = query.sortDescriptors?.compactMap { CKWSSortDescriptorDictionary(fieldName: $0.key, ascending: $0.ascending) }
        let queryDict = CKWSQueryDictionary(recordType: query.recordType, filterBy: filterBy, sortBy: sortBy)
        let queryRequest = CKWSQueryRequest(zoneID: zoneIDDict, resultsLimit: nil, query: queryDict)
        if let data = try? CloudyKitConfig.encoder.encode(queryRequest), let privateKey = CloudyKitConfig.serverPrivateKey {
            let signature = CKRequestSignature(data: data, date: now, path: path, privateKey: privateKey)
            if let signatureValue = try? signature.sign() {
                request.addValue(signatureValue, forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1")
            }
            request.httpBody = data
        }
        return request
    }
    
}
