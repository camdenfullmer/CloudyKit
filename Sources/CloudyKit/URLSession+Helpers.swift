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
    internal func successfulDataTask(with request: URLRequest, completionHandler: @escaping (Data?, Error?) -> Void) -> NetworkSessionDataTask {
        return self.internalDataTask(with: request) { data, response, error in
            if let error = error {
                completionHandler(nil, error)
                return
            }
            guard let response = response as? HTTPURLResponse else {
                completionHandler(nil, CKError(code: .internalError))
                return
            }
            if let data = data {
                if CloudyKitConfig.debug {
                    print("=== CloudKit Web Services Response ===")
                    print("Status Code: \(response.statusCode)")
                    print("Data:")
                    print("\(String(data: data, encoding: .utf8) ?? "invalid data")")
                    print("======================================")
                }
            }
            guard response.statusCode == 200 else {
                if let data = data {
                    if let ckwsError = try? CloudyKitConfig.decoder.decode(CKWSErrorResponse.self, from: data) {
                        if CloudyKitConfig.debug {
                            print("error: \(ckwsError)")
                        }
                        completionHandler(nil, ckwsError.ckError)
                        return
                    }
                    completionHandler(nil, CKError(code: .internalError))
                    return
                }
                // TODO: Handle error
                completionHandler(nil, CKError(code: .internalError))
                return
            }
            guard let data = data else {
                // TODO: Handle error
                completionHandler(nil, CKError(code: .internalError))
                return
            }
            if let ckwsError = try? CloudyKitConfig.decoder.decode(CKWSErrorResponse.self, from: data) {
                completionHandler(nil, ckwsError.ckError)
                return
            }
            
            completionHandler(data, nil)
        }
    }
    
    internal func recordResponseTask(with request: URLRequest, completionHandler: @escaping (CKRecord?, Error?) -> Void) -> NetworkSessionDataTask {
        return self.successfulDataTask(with: request) { (data, error) in
            if let error = error {
                completionHandler(nil, error)
            }
            if let data = data {
                do {
                    let response = try CloudyKitConfig.decoder.decode(CKWSRecordResponse.self, from: data)
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
                } catch {
                    completionHandler(nil, error)
                }
            }
        }
    }
    
    internal func recordIDResponseTask(with request: URLRequest, completionHandler: @escaping (CKRecord.ID?, Error?) -> Void) -> NetworkSessionDataTask {
        return self.successfulDataTask(with: request) { (data, error) in
            if let error = error {
                completionHandler(nil, error)
            }
            if let data = data {
                do {
                    let response = try CloudyKitConfig.decoder.decode(CKWSRecordResponse.self, from: data)
                    guard let responseRecord = response.records.first else {
                        completionHandler(nil, CKError(code: .internalError))
                        return
                    }
                    let id = CKRecord.ID(recordName: responseRecord.recordName)
                    completionHandler(id, nil)
                } catch {
                    if CloudyKitConfig.debug {
                        print("error decoding: \(error.localizedDescription)")
                        print("data: \(String(data: data, encoding: .utf8) ?? "no data")")
                    }
                    completionHandler(nil, error)
                }
            }
        }
    }
    
    internal func modelResponseTask<Model: Decodable>(with request: URLRequest, completionHandler: @escaping (Model?, Error?) -> Void) -> NetworkSessionDataTask {
        return self.successfulDataTask(with: request) { (data, error) in
            if let error = error {
                completionHandler(nil, error)
            }
            if let data = data {
                do {
                    let model = try CloudyKitConfig.decoder.decode(Model.self, from: data)
                    completionHandler(model, nil)
                } catch {
                    completionHandler(nil, error)
                }
            }
        }
    }
    
    internal func saveTask(database: CKDatabase, environment: CloudyKitConfig.Environment, record: CKRecord, completionHandler: @escaping (CKRecord?, Error?) -> Void) -> NetworkSessionDataTask {
        let now = Date()
        let path = "/database/1/\(database.containerIdentifier)/\(environment.rawValue)/\(database.databaseScope.description)/records/modify"
        var request = URLRequest(url: URL(string: "\(CloudyKitConfig.host)\(path)")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(CloudyKitConfig.serverKeyID, forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID")
        request.addValue(CloudyKitConfig.dateFormatter.string(from: now), forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date")
        
        let fields: [String:CKWSRecordFieldValue] = record.fields.compactMapValues {
            switch $0 {
            case let value as Int: return CKWSRecordFieldValue(value: .number(value), type: nil)
            case let value as String: return CKWSRecordFieldValue(value: .string(value), type: nil)
            case let value as CKAsset: return CKWSRecordFieldValue(value: .asset(value), type: nil)
            default:
                if CloudyKitConfig.debug {
                    print("unable to handle type: \(type(of: $0)) (\($0))")
                }
                return nil
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
        return self.recordResponseTask(with: request, completionHandler: completionHandler)
    }
    
    internal func fetchTask(database: CKDatabase, environment: CloudyKitConfig.Environment, recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void) -> NetworkSessionDataTask {
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
        return self.recordResponseTask(with: request, completionHandler: completionHandler)
    }
    
    internal func deleteTaskPublisher(database: CKDatabase, environment: CloudyKitConfig.Environment, recordID: CKRecord.ID) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
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
        return CloudyKitConfig.urlSession.internalDataTaskPublisher(for: request)
    }
    
    internal func deleteTask(database: CKDatabase, environment: CloudyKitConfig.Environment, recordID: CKRecord.ID, completionHandler: @escaping (CKRecord.ID?, Error?) -> Void) -> NetworkSessionDataTask {
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
        return self.recordIDResponseTask(with: request, completionHandler: completionHandler)
    }
    
    internal func requestAssetTokenTask(database: CKDatabase, environment: CloudyKitConfig.Environment, tokenRequest: CKWSAssetTokenRequest, completionHandler: @escaping ([CKWSTokenResponseDictionary]?, Error?) -> Void) -> NetworkSessionDataTask {
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
        return self.modelResponseTask(with: request, completionHandler: completionHandler)
    }
}
