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
        
        // Create publisher for any assets we need to upload.
        let assets = record.fields.compactMapValues { $0 as? CKAsset }
        let assetLists = record.fields
            .compactMapValues { $0 as? [CKAsset] }
            .filter { !$0.value.isEmpty }
        if assets.count + assetLists.count > 0 {
            var dictionarys: [CKWSAssetFieldDictionary] = assets.compactMap { fieldName, value in
                return CKWSAssetFieldDictionary(recordName: record.recordID.recordName,
                                                recordType: record.recordType,
                                                fieldName: fieldName)
            }
            let dictionaryLists: [[CKWSAssetFieldDictionary]] = assetLists.compactMap { fieldName, value in
                let dict = CKWSAssetFieldDictionary(recordName: record.recordID.recordName,
                                                    recordType: record.recordType,
                                                    fieldName: fieldName)
                return Array(repeating: dict, count: value.count)
            }
            for list in dictionaryLists {
                dictionarys.append(contentsOf: list)
            }
            let tokenRequest = CKWSAssetTokenRequest(tokens: dictionarys)
            let publisher = CloudyKitConfig.urlSession.requestAssetTokenTaskPublisher(database: self,
                                                                                      environment: CloudyKitConfig.environment,
                                                                                      tokenRequest: tokenRequest)
            self.cancellable = publisher.decode(type: CKWSTokenResponse.self, decoder: CloudyKitConfig.decoder)
                .flatMap { tokenResponse -> AnyPublisher<[(String, CKWSAssetUploadResponse)], Error> in
                    var usedFileURLs: [String:[URL]] = [:]
                    let publishers: [AnyPublisher<(String, CKWSAssetUploadResponse), Error>] = tokenResponse.tokens.compactMap { token in
                        let assetListURL = assetLists[token.fieldName]?.first(where: {
                            guard let fileURL = $0.fileURL else {
                                return false
                            }
                            if let usedURLs = usedFileURLs[token.fieldName]  {
                                return !usedURLs.contains(fileURL)
                            }
                            return true
                        })?.fileURL
                        guard let tokenURL = URL(string: token.url),
                              let fileURL = assets[token.fieldName]?.fileURL ?? assetListURL,
                              let data = try? Data(contentsOf: fileURL) else {
                            return nil
                        }
                        if var usedURLs = usedFileURLs[token.fieldName] {
                            usedURLs.append(fileURL)
                            usedFileURLs[token.fieldName] = usedURLs
                        } else {
                            usedFileURLs[token.fieldName] = [fileURL]
                        }
                        let boundary = UUID().uuidString
                        var request = URLRequest(url: tokenURL)
                        request.httpMethod = "POST"
                        request.addValue("application/json", forHTTPHeaderField: "Accept")
                        request.addValue("multipart/form-data; boundary=----\(boundary)", forHTTPHeaderField: "Content-Type")
                        var body = "------\(boundary)\r\n".data(using: .utf8) ?? Data()
                        body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(fileURL.lastPathComponent)\"\r\n\r\n".data(using: .utf8) ?? Data())
                        body.append(data)
                        body.append("\r\n------\(boundary)--\r\n".data(using: .utf8) ?? Data())
                        request.httpBody = body
                        return CloudyKitConfig.urlSession.successfulDataTaskPublisher(for: request)
                            .decode(type: CKWSAssetUploadResponse.self, decoder: CloudyKitConfig.decoder)
                            .map { return (token.fieldName, $0) }
                            .eraseToAnyPublisher()
                    }
                    #if os(Linux)
                    // TODO: OpenCombine does not yet support Publishers.MergeMany. Only uploading
                    //       the first asset. https://github.com/OpenCombine/OpenCombine/issues/141
                    let publisher = publishers.first?.eraseToAnyPublisher() ?? Empty<(String, CKWSAssetUploadResponse), Error>().eraseToAnyPublisher()
                    return publisher
                        .map { [$0] }
                        .eraseToAnyPublisher()
                    #else
                    return Publishers.MergeMany(publishers)
                        .collect()
                        .eraseToAnyPublisher()
                    #endif
                }.flatMap { assetUploadResponses in
                    return CloudyKitConfig.urlSession.saveTaskPublisher(database: self,
                                                                        environment: CloudyKitConfig.environment,
                                                                        record: record,
                                                                        assetUploadResponses: assetUploadResponses)
                }.sink { completion in
                    switch completion {
                    case .failure(let error): completionHandler(nil, error)
                    default: break
                    }
                } receiveValue: { record in
                    completionHandler(record, nil)
                }
        } else {
            self.cancellable = CloudyKitConfig.urlSession.saveTaskPublisher(database: self, environment: CloudyKitConfig.environment, record: record)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        completionHandler(nil, error)
                    }
                }, receiveValue: { record in
                    completionHandler(record, nil)
                })
        }
    }
    
    public func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void) {
        self.cancellable = CloudyKitConfig.urlSession.fetchTaskPublisher(database: self, environment: CloudyKitConfig.environment, recordID: recordID)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    completionHandler(nil, error)
                case .finished: break
                }
            }, receiveValue: { record in
                completionHandler(record, nil)
            })
    }
    
    public func delete(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord.ID?, Error?) -> Void) {
        self.cancellable = CloudyKitConfig.urlSession.deleteTaskPublisher(database: self, environment: CloudyKitConfig.environment, recordID: recordID)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    completionHandler(nil, error)
                }
            }, receiveValue: { response in
                guard let responseRecord = response.records.first else {
                    completionHandler(nil, CKError(code: .internalError, userInfo: [:]))
                    return
                }
                let recordID = CKRecord.ID(recordName: responseRecord.recordName)
                completionHandler(recordID, nil)
            })
    }
    
    public func perform(_ query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?, completionHandler: @escaping ([CKRecord]?, Error?) -> Void) {
        self.cancellable = CloudyKitConfig.urlSession.queryTaskPublisher(database: self, environment: CloudyKitConfig.environment, query: query, zoneID: zoneID)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    completionHandler(nil, error)
                case .finished: break
                }
            }, receiveValue: { record in
                completionHandler(record, nil)
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
