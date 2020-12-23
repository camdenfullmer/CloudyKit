//
//  CKRequestSignature.swift
//  
//
//  Created by Camden on 12/22/20.
//

import Foundation
import Cryptor
import CryptorECC

class CKRequestSignature {
    
    let data: Data
    let date: Date
    let path: String
    let ecPrivateKey: ECPrivateKey
    
    init(data: Data, date: Date, path: String, ecPrivateKey: ECPrivateKey) {
        self.data = data
        self.date = date
        self.path = path
        self.ecPrivateKey = ecPrivateKey
    }
    
    func sign() throws -> String {
        let digest = Digest(using: .sha256)
        guard let dataDigest = digest.update(data: data) else {
            throw CKError(code: .internalError)
        }
        let hash = dataDigest.final()
        let base64BodyHash = Data(bytes: hash, count: hash.count).base64EncodedString()
        let signaturePayload = "\(CloudyKitConfig.dateFormatter.string(from: date)):\(base64BodyHash):\(path)"
        return try signaturePayload.sign(with: self.ecPrivateKey).asn1.base64EncodedString()
    }
    
}
