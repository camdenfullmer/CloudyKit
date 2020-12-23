//
//  CKPrivateKey.swift
//  
//
//  Created by Camden on 12/22/20.
//

import Foundation
import Cryptor
import CryptorECC

public class CKPrivateKey {
    
    internal let ecPrivateKey: ECPrivateKey
    
    public init(path: String) throws {
        let key = try String(contentsOfFile: path)
        self.ecPrivateKey = try ECPrivateKey(key: key)
    }
    
    public convenience init(data: Data) throws {
        let string = String(data: data, encoding: .utf8) ?? ""
        try self.init(string: string)
    }
    
    public init(string: String) throws {
        self.ecPrivateKey = try ECPrivateKey(key: string)
    }
    
}
