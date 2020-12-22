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
        // TODO: Get from CloudyKit config
//        request.addValue(environment.keyID, forHTTPHeaderField: "X-Apple-CloudKit-Request-KeyID")
        request.addValue(CloudyKitConfig.dateFormatter.string(from: now), forHTTPHeaderField: "X-Apple-CloudKit-Request-ISO8601Date")
//        let data = try! JSONEncoder().encode(QueryRequest(query: query))
//        let signature = environment.signature(for: data, date: date, path: path)
//        request.addValue(signature, forHTTPHeaderField: "X-Apple-CloudKit-Request-SignatureV1")
//        request.httpBody = data
        return self.successfulDataTask(with: request) { (data, error) in
            if let error = error {
                completionHandler(nil, error)
            }
            if let data = data {
                do {
                    let response = try CloudyKitConfig.decoder.decode(CKModifyRecordResponse.self, from: data)
                    guard let responseRecord = response.records.first else {
                        completionHandler(nil, CKError(code: .internalError))
                        return
                    }
                    let id = CKRecord.ID(recordName: responseRecord.recordName)
                    let record = CKRecord(recordType: responseRecord.recordType, recordID: id)
                    completionHandler(record, nil)
                } catch {
                    completionHandler(nil, error)
                }
            }
        }
    }
}
