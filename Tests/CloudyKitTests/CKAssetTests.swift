//
//  CKAssetsTests.swift
//  
//
//  Created by Camden on 12/23/20.
//

import XCTest
import CloudyKit

final class CKAssetTests: XCTestCase {
    
    func testInit() {
        guard let fileURL = assetURL(name: "cloudkit-128x128.png") else {
            XCTFail("unable to locate asset")
            return
        }
        let asset = CloudyKit.CKAsset(fileURL: fileURL)
        XCTAssertNotNil(asset.fileURL)
        XCTAssertNotEqual(fileURL, asset.fileURL)
    }

    static var allTests = [
        ("testInit", testInit),
    ]
}
