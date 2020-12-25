//
//  CKDatabase.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation
#if os(Linux)
import FoundationNetworking
import OpenCombine
#else
import Combine
#endif

public class CKDatabase {
    
    public enum Scope: Int {
        case `public` = 1
        case `private` = 2
        case shared = 3
    }
    
    public let databaseScope: Scope
    
    internal let containerIdentifier: String
    
    internal init(containerIdentifier: String, databaseScope: Scope) {
        self.containerIdentifier = containerIdentifier
        self.databaseScope = databaseScope
    }
    
    var cancellable: AnyCancellable? = nil
    
    public func save(_ record: CKRecord, completionHandler: @escaping (CKRecord?, Error?) -> Void) {        
//        let assetFieldDictionarys: [CKWSAssetFieldDictionary] = record.fields.compactMap { fieldName, value in
//            guard value is CKAsset else {
//                return nil
//            }
//            return CKWSAssetFieldDictionary(recordName: record.recordID.recordName,
//                                            recordType: record.recordType,
//                                            fieldName: fieldName)
//        }
//        if assetFieldDictionarys.count > 0 {
//            let tokenRequest = CKWSAssetTokenRequest(tokens: assetFieldDictionarys)
//            let task = CloudyKitConfig.urlSession.requestAssetTokenTask(database: self, environment: CloudyKitConfig.environment, tokenRequest: tokenRequest) { (tokenResponse, error) in
//                // TODO:
//            }
//            task.resume()
//        }
        self.cancellable = CloudyKitConfig.urlSession.saveTaskPublisher(database: self, environment: CloudyKitConfig.environment, record: record)
            .decode(type: CKWSRecordResponse.self, decoder: CloudyKitConfig.decoder)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    completionHandler(nil, error)
                }
            }, receiveValue: { response in
                guard let responseRecord = response.records.first,
                      let recordType = responseRecord.recordType,
                      let createdTimestamp = responseRecord.created?.timestamp else {
                    completionHandler(nil, CKError(code: .internalError))
                    return
                }
                let id = CKRecord.ID(recordName: responseRecord.recordName)
                let record = CKRecord(recordType: recordType, recordID: id)
                record.creationDate = Date(timeIntervalSince1970: TimeInterval(createdTimestamp) / 1000)
                record.recordChangeTag = responseRecord.recordChangeTag
                for (fieldName, fieldValue) in responseRecord.fields ?? [:] {
                    switch fieldValue.value {
                    case .string(let value): record[fieldName] = value
                    case .number(let value): record[fieldName] = value
                    case .asset(_): fatalError("not supported")
                    }
                }
                completionHandler(record, nil)
            })
    }
    
    public func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void) {
        self.cancellable = CloudyKitConfig.urlSession.fetchTaskPublisher(database: self, environment: CloudyKitConfig.environment, recordID: recordID)
            .decode(type: CKWSRecordResponse.self, decoder: CloudyKitConfig.decoder)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    completionHandler(nil, error)
                }
            }, receiveValue: { response in
                guard let responseRecord = response.records.first,
                      let recordType = responseRecord.recordType,
                      let createdTimestamp = responseRecord.created?.timestamp else {
                    completionHandler(nil, CKError(code: .internalError))
                    return
                }
                let id = CKRecord.ID(recordName: responseRecord.recordName)
                let record = CKRecord(recordType: recordType, recordID: id)
                record.creationDate = Date(timeIntervalSince1970: TimeInterval(createdTimestamp) / 1000)
                record.recordChangeTag = responseRecord.recordChangeTag
                for (fieldName, fieldValue) in responseRecord.fields ?? [:] {
                    switch fieldValue.value {
                    case .string(let value): record[fieldName] = value
                    case .number(let value): record[fieldName] = value
                    case .asset(_): fatalError("not supported")
                    }
                }
                completionHandler(record, nil)
            })
    }
    
    public func delete(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord.ID?, Error?) -> Void) {
        self.cancellable = CloudyKitConfig.urlSession.deleteTaskPublisher(database: self, environment: CloudyKitConfig.environment, recordID: recordID)
            .decode(type: CKWSRecordResponse.self, decoder: CloudyKitConfig.decoder)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    completionHandler(nil, error)
                }
            }, receiveValue: { response in
                guard let responseRecord = response.records.first else {
                    completionHandler(nil, CKError(code: .internalError))
                    return
                }
                let recordID = CKRecord.ID(recordName: responseRecord.recordName)
                completionHandler(recordID, nil)
            })
    }
}

extension CKDatabase.Scope: CustomStringConvertible {
    public var description: String {
        switch self {
        case .private: return "private"
        case .public: return "public"
        case .shared: return "shared"
        }
    }
}
