//
//  String+Helpers.swift
//  
//
//  Created by Camden on 12/27/20.
//

import Foundation

#if os(Linux)
extension String: CVarArg {
    public var _cVarArgEncoding: [Int] {
        return [unsafeBitCast(self, to: Int.self)]
    }
}
#endif
