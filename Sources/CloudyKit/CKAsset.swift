//
//  CKAsset.swift
//  
//
//  Created by Camden on 12/23/20.
//

import Foundation

public class CKAsset {
    
    public let fileURL: URL?
    
    public init(fileURL: URL) {
        let fileManager = FileManager.default
        let uuid = UUID()
        let tmpFileURL = fileManager.temporaryDirectory.appendingPathComponent(uuid.uuidString)
        do {
            try fileManager.copyItem(at: fileURL, to: tmpFileURL)
            self.fileURL = tmpFileURL
        } catch {
            self.fileURL = nil
        }
    }

}
