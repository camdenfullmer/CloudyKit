//
//  Assets.swift
//  
//
//  Created by Camden on 12/22/20.
//

import Foundation

extension Data {
    
    static func loadAsset(name: String) throws -> Data {
        guard let fileURL = assetURL(name: name) else {
            throw NSError(
                domain: "CloudyKitTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "unable to locate asset named \(name)"]
            )
        }
        return try Data(contentsOf: fileURL)
    }
    
}

func assetURL(name: String) -> URL? {
    let nsName = name as NSString
    let resource = nsName.deletingPathExtension
    let ext = nsName.pathExtension.isEmpty ? nil : nsName.pathExtension
    if let url = Bundle.module.url(forResource: resource, withExtension: ext, subdirectory: "Assets") {
        return url
    }
    if let url = Bundle.module.url(forResource: resource, withExtension: ext) {
        return url
    }
    return nil
}
