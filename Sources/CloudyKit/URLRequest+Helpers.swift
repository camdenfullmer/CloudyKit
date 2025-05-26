//
//  URLRequest+Helpers.swift
//  CloudyKit
//
//  Created by Camden on 5/26/25.
//

import Foundation

extension URLRequest {
    
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
