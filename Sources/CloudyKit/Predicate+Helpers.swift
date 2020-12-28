//
//  NSPredicate+Helpers.swift
//  
//
//  Created by Camden on 12/26/20.
//

import Foundation

#if os(Linux)
public typealias Predicate = CKPredicate
#else
public typealias Predicate = CKPredicate
#endif

public class CKPredicate {
    
    public let predicateFormat: String
    
    public init(value: Bool) {
        self.predicateFormat = value ? "TRUEPREDICATE" : "FALSEPREDICATE"
    }
    
    public init(format predicateFormat: String, _ arguments: Any...) {
        var argumentsLeft = arguments
        let splits: [String] = predicateFormat.components(separatedBy: "%@")
        var substitution = ""
        for (index, split) in splits.enumerated() {
            if index > 0, arguments.count > 0 {
                let argument = argumentsLeft.removeFirst()
                switch argument {
                case is String:
                    substitution += "\"\(argument)\""
                default:
                    substitution += "\(argument)"
                }
            }
            let keyPathSplits = split.components(separatedBy: "%K")
            if keyPathSplits.count > 1 {
                for (keyPathIndex, keyPathSplit) in keyPathSplits.enumerated() {
                    if keyPathIndex > 0, arguments.count > 0 {
                        let argument = argumentsLeft.removeFirst()
                        substitution += "\(argument)"
                    }
                    substitution += "\(keyPathSplit)"
                }
            } else {
                substitution += split.replacingOccurrences(of: "'", with: "\"")
            }
        }
        self.predicateFormat = substitution
    }
}

extension Predicate {
    
    var filterBy: [CKWSFilterDictionary]? {
        guard self.predicateFormat != "TRUEPREDICATE" else {
            return []
        }
        guard self.predicateFormat != "FALSEPREDICATE" else {
            fatalError("invalid predicate: \(self.predicateFormat)")
        }
        
        var filters: [CKWSFilterDictionary] = []
        let (originalComparator, fields) = self.comparatorWithFields()
        var comparator = originalComparator
        var fieldName: String?
        var fieldValue: CKWSRecordFieldValue?
        for field in fields {
            if field.hasPrefix("<") && field.hasSuffix(">") {
                if field.hasPrefix("<CKReference:") {
                    if field.contains("recordName="),
                       let recordName = field.components(separatedBy: "recordName=").last?.split(separator: ",").first {
                        let referenceDictionary = CKWSReferenceDictionary(recordName: String(recordName), action: "NONE")
                        fieldValue = CKWSRecordFieldValue(value: .reference(referenceDictionary), type: nil)
                    }
                }
            } else if (field.hasPrefix("ANY {") || field.hasPrefix("{")) && field.hasSuffix("}"){
                comparator = .in
                let firstSeparation = field.hasPrefix("{") ? "{" : "ANY {"
                let listValues = field.components(separatedBy: firstSeparation).last?
                    .components(separatedBy: "}").first?
                    .components(separatedBy: ", ")
                    .map {
                        $0.trimmingCharacters(in: CharacterSet(["\"", " "]))
                    } ?? []
                fieldValue = CKWSRecordFieldValue(value: .stringList(listValues), type: nil)
            } else if field.hasPrefix("\"") && field.hasSuffix("\"") {
                fieldValue = CKWSRecordFieldValue(value: .string(field.trimmingCharacters(in: CharacterSet(["\""]))), type: nil)
            } else {
                if field.hasPrefix("ANY ") {
                    if originalComparator == .equals {
                        comparator = .listContains
                    }
                    fieldName = String(field.split(separator: " ").last ?? "")
                } else {
                    fieldName = field
                }
            }
        }
        if originalComparator == .in, let lastField = fields.last, let fieldName = fieldName, fieldName == lastField {
            comparator = .listContains
        }
        
        guard let fv = fieldValue, let fn = fieldName else {
            fatalError("invalid predicate: \(self.predicateFormat)")
        }
        filters.append(CKWSFilterDictionary(comparator: comparator, fieldName: fn, fieldValue: fv))
        return filters
    }
    
    private func comparatorWithFields() -> (CKWSFilterDictionary.Comparator, [String]) {
        let doubleEqualsSplits = self.predicateFormat.components(separatedBy: "==")
        let equalsSplits = self.predicateFormat.components(separatedBy: "=")
        let containsSplits = self.predicateFormat.components(separatedBy: "CONTAINS")
        let beginsWithSplits = self.predicateFormat.components(separatedBy: "BEGINSWITH")
        let inSplits = self.predicateFormat.components(separatedBy: "IN")
        if doubleEqualsSplits.count == 2 {
            let fields = doubleEqualsSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.equals, fields)
        } else if equalsSplits.count == 2 {
            let fields = equalsSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.equals, fields)
        } else if containsSplits.count == 2 {
            let fields = containsSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.listContains, fields)
        } else if beginsWithSplits.count == 2 {
            let fields = beginsWithSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.beginsWith, fields)
        } else if inSplits.count == 2 {
            let fields = inSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.in, fields)
        }
        fatalError("invalid predicate: \(self.predicateFormat)")
    }
    
}
