//
//  CKRecordZone.swift
//  
//
//  Created by Camden on 12/26/20.
//

import Foundation

public class CKRecordZone {
    
    public class ID {
        
        public static let defaultZoneName = "_defaultZone"
        
        public let zoneName: String
        public let ownerName: String
        
        public init(zoneName: String = CKRecordZone.ID.defaultZoneName, ownerName: String = CKCurrentUserDefaultName) {
            self.zoneName = zoneName
            self.ownerName = ownerName
        }
    }
    
}
