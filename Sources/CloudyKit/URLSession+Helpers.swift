//
//  URLSession+Helpers.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation
#if os(Linux)
import FoundationNetworking
import OpenCombine
import OpenCombineFoundation
#else
import Combine
#endif

internal protocol NetworkSession {
    func internalDataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkSessionDataTask
    func internalDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error>
}

internal protocol NetworkSessionDataTask {
    func resume()
}

extension URLSession: NetworkSession {
    func internalDataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkSessionDataTask {
        return self.dataTask(with: request, completionHandler: completionHandler)
    }
    
    func internalDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        return self.dataTaskPublisher(for: request)
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
}

extension URLSessionDataTask: NetworkSessionDataTask { }

extension NetworkSession {
    internal func successfulDataTaskPublisher(for request: URLRequest) -> AnyPublisher<Data, Error> {
        return self.internalDataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    throw CKError(code: .internalError)
                }
                if CloudyKitConfig.debug {
                    print("=== CloudKit Web Services Request ===")
                    print("URL: \(request.url?.absoluteString ?? "no url")")
                    print("Method: \(request.httpMethod ?? "no method")")
                    print("Data:")
                    print("\(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "no data")")
                    print("======================================")
                    print("=== CloudKit Web Services Response ===")
                    print("Status Code: \(response.statusCode)")
                    print("Data:")
                    print("\(String(data: output.data, encoding: .utf8) ?? "invalid data")")
                    print("======================================")
                }
                if let ckwsError = try? CloudyKitConfig.decoder.decode(CKWSErrorResponse.self, from: output.data) {
                    if CloudyKitConfig.debug {
                        print("error: \(ckwsError)")
                    }
                    throw ckwsError.ckError
                }
                guard response.statusCode == 200 else {
                    throw CKError(code: .internalError)
                }
                return output.data
            }.eraseToAnyPublisher()
    }
    
    internal func recordTaskPublisher(for request: URLRequest) -> AnyPublisher<CKRecord, Error> {
        return self.successfulDataTaskPublisher(for: request)
            .decode(type: CKWSRecordResponse.self, decoder: CloudyKitConfig.decoder)
            .tryMap { response in
                guard let responseRecord = response.records.first,
                      let record = CKRecord(ckwsRecordResponse: responseRecord) else {
                    throw CKError(code: .internalError)
                }
                return record
            }.eraseToAnyPublisher()
    }
    
    internal func recordsTaskPublisher(for request: URLRequest) -> AnyPublisher<[CKRecord], Error> {
        return self.successfulDataTaskPublisher(for: request)
            .decode(type: CKWSRecordResponse.self, decoder: CloudyKitConfig.decoder)
            .tryMap { $0.records.compactMap { CKRecord(ckwsRecordResponse: $0) } }
            .eraseToAnyPublisher()
    }
    
    internal func saveTaskPublisher(database: CKDatabase, environment: CloudyKitConfig.Environment, record: CKRecord, assetUploadResponses: [(String, CKWSAssetUploadResponse)] = []) -> AnyPublisher<CKRecord, Error> {
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
            default:
                fatalError("unable to handle \(value) of type \(type(of: value))")
            }
        }
        let recordDictionary = CKWSRecordDictionary(recordName: record.recordID.recordName,
                                                    recordType: record.recordType,
                                                    recordChangeTag: record.recordChangeTag,
                                                    fields: fields,
                                                    created: nil)
        let operationType: CKWSRecordOperation.OperationType = record.creationDate == nil ? .create : .update
        let operation = CKWSRecordOperation(operationType: operationType,
                                            desiredKeys: nil,
                                            record: recordDictionary)
        let modifyRequest = CKWSModifyRecordRequest(operations: [operation])
        if let data = try? CloudyKitConfig.encoder.encode(modifyRequest), let privateKey = CloudyKitConfig.serverPrivateKey {
            let signature = CKRequestSignature(data: data, date: now, path: path, privateKey: privateKey)
            if let signatureValue = try? signature.sign() {
                request.addValue(signatureValue, forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1")
            }
            request.httpBody = data
        }
        return self.recordTaskPublisher(for: request)
    }
    
    internal func fetchTaskPublisher(database: CKDatabase, environment: CloudyKitConfig.Environment, recordID: CKRecord.ID) -> AnyPublisher<CKRecord, Error> {
        let now = Date()
        let path = "/database/1/\(database.containerIdentifier)/\(environment.rawValue)/\(database.databaseScope.description)/records/lookup"
        var request = URLRequest(url: URL(string: "\(CloudyKitConfig.host)\(path)")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(CloudyKitConfig.serverKeyID, forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID")
        request.addValue(CloudyKitConfig.dateFormatter.string(from: now), forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date")
        let records = [
            CKWSLookupRecordDictionary(recordName: recordID.recordName)
        ]
        let fetchRequest = CKWSFetchRecordRequest(records: records)
        if let data = try? CloudyKitConfig.encoder.encode(fetchRequest), let privateKey = CloudyKitConfig.serverPrivateKey {
            let signature = CKRequestSignature(data: data, date: now, path: path, privateKey: privateKey)
            if let signatureValue = try? signature.sign() {
                request.addValue(signatureValue, forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1")
            }
            request.httpBody = data
        }
        return self.recordTaskPublisher(for: request)
    }
    
    internal func queryTaskPublisher(database: CKDatabase, environment: CloudyKitConfig.Environment, query: CKQuery, zoneID: CKRecordZone.ID?) -> AnyPublisher<[CKRecord], Error> {
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
        return self.recordsTaskPublisher(for: request)
    }
    
    internal func deleteTaskPublisher(database: CKDatabase, environment: CloudyKitConfig.Environment, recordID: CKRecord.ID) -> AnyPublisher<CKWSRecordResponse, Error> {
        let now = Date()
        let path = "/database/1/\(database.containerIdentifier)/\(environment.rawValue)/\(database.databaseScope.description)/records/modify"
        var request = URLRequest(url: URL(string: "\(CloudyKitConfig.host)\(path)")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(CloudyKitConfig.serverKeyID, forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID")
        request.addValue(CloudyKitConfig.dateFormatter.string(from: now), forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date")
        let recordDictionary = CKWSRecordDictionary(recordName: recordID.recordName,
                                                    recordType: nil,
                                                    recordChangeTag: nil,
                                                    fields: nil,
                                                    created: nil)
        let operationType: CKWSRecordOperation.OperationType = .forceDelete
        let operation = CKWSRecordOperation(operationType: operationType,
                                            desiredKeys: nil,
                                            record: recordDictionary)
        let modifyRequest = CKWSModifyRecordRequest(operations: [operation])
        if let data = try? CloudyKitConfig.encoder.encode(modifyRequest), let privateKey = CloudyKitConfig.serverPrivateKey {
            let signature = CKRequestSignature(data: data, date: now, path: path, privateKey: privateKey)
            if let signatureValue = try? signature.sign() {
                request.addValue(signatureValue, forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1")
            }
            request.httpBody = data
        }
        return self.successfulDataTaskPublisher(for: request)
            .decode(type: CKWSRecordResponse.self, decoder: CloudyKitConfig.decoder)
            .eraseToAnyPublisher()
    }

    internal func requestAssetTokenTaskPublisher(database: CKDatabase, environment: CloudyKitConfig.Environment, tokenRequest: CKWSAssetTokenRequest) -> AnyPublisher<Data, Error> {
        let now = Date()
        let path = "/database/1/\(database.containerIdentifier)/\(environment.rawValue)/\(database.databaseScope.description)/assets/upload"
        var request = URLRequest(url: URL(string: "\(CloudyKitConfig.host)\(path)")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(CloudyKitConfig.serverKeyID, forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID")
        request.addValue(CloudyKitConfig.dateFormatter.string(from: now), forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date")
        if let data = try? CloudyKitConfig.encoder.encode(tokenRequest), let privateKey = CloudyKitConfig.serverPrivateKey {
            let signature = CKRequestSignature(data: data, date: now, path: path, privateKey: privateKey)
            if let signatureValue = try? signature.sign() {
                request.addValue(signatureValue, forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1")
            }
            request.httpBody = data
        }
        return self.successfulDataTaskPublisher(for: request)
    }
}

extension CKRecord {
    
    convenience init?(ckwsRecordResponse: CKWSRecordDictionary) {
        guard let recordType = ckwsRecordResponse.recordType,
              let createdTimestamp = ckwsRecordResponse.created?.timestamp else {
            return nil
        }
        let id = CKRecord.ID(recordName: ckwsRecordResponse.recordName)
        self.init(recordType: recordType, recordID: id)
        self.creationDate = Date(timeIntervalSince1970: TimeInterval(createdTimestamp) / 1000)
        self.recordChangeTag = ckwsRecordResponse.recordChangeTag
        self.fields = [:]
        for (fieldName, fieldValue) in ckwsRecordResponse.fields ?? [:] {
            switch fieldValue.value {
            case .string(let value): self.fields[fieldName] = value
            case .number(let value): self.fields[fieldName] = value
            case .asset(let value):
                guard let downloadURL = value.downloadURL, let fileURL = URL(string: downloadURL.replacingOccurrences(of: "${f}", with: value.fileChecksum)) else {
                    return nil
                }
                self.fields[fieldName] = CKAsset(fileURL: fileURL)
            case .assetList(let value):
                var assets: [CKAsset] = []
                for dict in value {
                    guard let downloadURL = dict.downloadURL, let fileURL = URL(string: downloadURL.replacingOccurrences(of: "${f}", with: dict.fileChecksum)) else {
                        return nil
                    }
                    assets.append(CKAsset(fileURL: fileURL))
                }
                self.fields[fieldName] = assets
            case .bytes(let value):
                self.fields[fieldName] = value
            case .bytesList(let value):
                self.fields[fieldName] = value
            case .double(let value):
                self.fields[fieldName] = value
            case .reference(let value):
                let recordID = CKRecord.ID(recordName: value.recordName)
                let action = CKRecord.Reference.Action(string: value.action)
                let reference = CKRecord.Reference(recordID: recordID, action: action)
                self.fields[fieldName] = reference
            case .dateTime(let value):
                self.fields[fieldName] = Date(timeIntervalSince1970: TimeInterval(value) / 1000)
            case .stringList(let value):
                self.fields[fieldName] = value
            }
        }
    }
    
}
