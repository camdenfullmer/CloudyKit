//
//  String+Components.swift
//
//
//  Created by Diego Trevisan on 11.12.23.
//

import Foundation

public extension String {
    func components(separatedByFirst separator: String) -> [String] {
        guard let range = self.range(of: separator) else {
            return [self]
        }

        let firstSegment = self[..<range.lowerBound]
            .trimmingCharacters(in: .whitespaces)
        let secondSegment = self[range.upperBound...]
            .trimmingCharacters(in: .whitespaces)

        return [
            String(firstSegment),
            String(secondSegment)
        ]
    }
}
