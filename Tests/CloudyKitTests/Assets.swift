//
//  Assets.swift
//  
//
//  Created by Camden on 12/22/20.
//

import Foundation

extension Data {
    
    static func loadAsset(name: String) throws -> Data {
        let path = #file.replacingOccurrences(of: "/Assets.swift", with: "/Assets/") + name
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }
    
}

func assetURL(name: String) -> URL? {
    let path = #file.replacingOccurrences(of: "/Assets.swift", with: "/Assets/") + name
    return URL(fileURLWithPath: path)
}
