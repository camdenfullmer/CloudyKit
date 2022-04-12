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
        case unknownItem = 11
        case invalidArguments = 12
    }
    
    public var errorCode: Int {
        return self.code.rawValue
    }
    
    public var errorUserInfo: [String:Any] {
        return self.userInfo
    }
    
    public var localizedDescription: String {
        return self.userInfo[NSLocalizedDescriptionKey] as? String ??
            "CKError \(self.code.rawValue)"
    }
    
    internal let code: Code
    internal let userInfo: [String:Any]
    
    internal init(code: Code, userInfo: [String:Any]) {
        self.code = code
        self.userInfo = userInfo
    }
}

extension CKError: LocalizedError {
    public var errorDescription: String? {
        return self.userInfo[NSLocalizedDescriptionKey] as? String ??
            "CKError \(self.code.rawValue)"
    }
}
