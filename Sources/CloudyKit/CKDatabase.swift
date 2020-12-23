//
//  CKDatabase.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation

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
    
    public func save(_ record: CKRecord, completionHandler: @escaping (CKRecord?, Error?) -> Void) {
        let task = CloudyKitConfig.urlSession.saveTask(database: self,
                                                       environment: CloudyKitConfig.environment,
                                                       record: record,
                                                       completionHandler: completionHandler)
        task.resume()
    }
    
    public func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void) {
        let task = CloudyKitConfig.urlSession.fetchTask(database: self,
                                                        environment: CloudyKitConfig.environment,
                                                        recordID: recordID,
                                                        completionHandler: completionHandler)
        task.resume()
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
