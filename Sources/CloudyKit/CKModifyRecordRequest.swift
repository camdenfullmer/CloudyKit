//
//  CKModifyRecordRequest.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation

struct CKRecordDictionary: Decodable {
    let recordName: String
    let recordType: String
    let recordChangeTag: String
}

struct CKModifyRecordRequest: Encodable {
    
}

struct CKModifyRecordResponse: Decodable {
    let records: [CKRecordDictionary]
}
