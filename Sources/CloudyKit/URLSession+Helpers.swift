//
//  URLSession+Helpers.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

internal protocol NetworkSession {
    func internalDataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkSessionDataTask
}

internal protocol NetworkSessionDataTask {
    func resume()
}

extension URLSession: NetworkSession {
    func internalDataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkSessionDataTask {
        return self.dataTask(with: request, completionHandler: completionHandler)
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
            guard response.statusCode == 200 else {
                if let data = data, let _ /* message */ = String(data: data, encoding: .utf8) {
                    // TODO: Handle error
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
            completionHandler(data, nil)
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
        
        let fields: [String:CKRecordFieldValue] = record.fields.compactMapValues {
            switch $0 {
            case let value as Int: return CKRecordFieldValue(value: .number(value), type: nil)
            case let value as String: return CKRecordFieldValue(value: .string(value), type: nil)
            // TODO: Add debug message here.
            default: return nil
            }
        }
        let recordDictionary = CKRecordDictionary(recordName: record.recordID.recordName,
                                                  recordType: record.recordType,
                                                  recordChangeTag: nil,
                                                  fields: fields,
                                                  created: nil)
        let operationType: CKRecordOperation.OperationType = record.creationDate == nil ? .create : .update
        let operation = CKRecordOperation(operationType: operationType, desiredKeys: nil, record: recordDictionary)
        let modifyRequest = CKModifyRecordRequest(operations: [operation])
        if let data = try? CloudyKitConfig.encoder.encode(modifyRequest), let privateKey = CloudyKitConfig.serverPrivateKey {
            let signature = CKRequestSignature(data: data, date: now, path: path, privateKey: privateKey)
            if let signatureValue = try? signature.sign() {
                request.addValue(signatureValue, forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1")
            }
            request.httpBody = data
        }
        return self.successfulDataTask(with: request) { (data, error) in
            if let error = error {
                completionHandler(nil, error)
            }
            if let data = data {
                do {
                    let response = try CloudyKitConfig.decoder.decode(CKModifyRecordResponse.self, from: data)
                    guard let responseRecord = response.records.first,
                          let recordType = responseRecord.recordType,
                          let createdTimestamp = responseRecord.created?.timestamp else {
                        completionHandler(nil, CKError(code: .internalError))
                        return
                    }
                    let id = CKRecord.ID(recordName: responseRecord.recordName)
                    let record = CKRecord(recordType: recordType, recordID: id)
                    record.creationDate = Date(timeIntervalSince1970: TimeInterval(createdTimestamp) / 1000)
                    for (fieldName, fieldValue) in responseRecord.fields ?? [:] {
                        switch fieldValue.value {
                        case .string(let value): record[fieldName] = value
                        case .number(let value): record[fieldName] = value
                        }
                    }
                    completionHandler(record, nil)
                } catch {
                    completionHandler(nil, error)
                }
            }
        }
    }
}
