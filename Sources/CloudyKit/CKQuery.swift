//
//  CKQuery.swift
//  
//
//  Created by Camden on 12/26/20.
//

import Foundation

#if os(Linux)
public typealias SortDescriptor = CKSortDescriptor
#else
public typealias SortDescriptor = NSSortDescriptor
#endif

public class CKSortDescriptor {
    public let key: String
    public let ascending: Bool
    public init(key: String, ascending: Bool) {
        self.key = key
        self.ascending = ascending
    }
}

public class CKQuery {
    
    public let recordType: CKRecord.RecordType
    public let predicate: Predicate
    public var sortDescriptors: [SortDescriptor]?
    
    public init(recordType: CKRecord.RecordType, predicate: Predicate) {
        self.recordType = recordType
        self.predicate = predicate
        self.sortDescriptors = nil
    }
    
}
