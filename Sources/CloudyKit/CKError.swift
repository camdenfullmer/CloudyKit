//
//  CKError.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation

public struct CKError: Error {
    public enum Code: Int {
        case internalError = 1
        case invalidArguments = 12
    }
    
    public var errorCode: Int {
        return code.rawValue
    }
    
    internal let code: Code
    
    internal init(code: Code) {
        self.code = code
    }
}
