//
//  String+ComponentsTests.swift
//  
//
//  Created by Diego Trevisan on 11.12.23.
//

import XCTest
import CloudyKit

final class StringTests: XCTestCase {
    
    func testSeparationWhenOneOccurrence() {
        var segments = "name IN {'Camden', 'Diego'}"
            .components(separatedByFirst: "IN")

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0], "name")
        XCTAssertEqual(segments[1], "{'Camden', 'Diego'}")
    }

    func testSeparationWhenMultipleOccurrences() {
        var segments = "app IN {'INSTAGRAM'}"
            .components(separatedByFirst: "IN")

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0], "app")
        XCTAssertEqual(segments[1], "{'INSTAGRAM'}")
    }

    func testSeparationWhenNoOccurrences() {
        var segments = "something == foo"
            .components(separatedByFirst: "IN")

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0], "something == foo")
    }

    static var allTests = [
        ("testSeparationWhenOneOccurrence", testSeparationWhenOneOccurrence),
        ("testSeparationWhenMultipleOccurrences", testSeparationWhenMultipleOccurrences),
        ("testSeparationWhenNoOccurrences", testSeparationWhenNoOccurrences)
    ]
}
