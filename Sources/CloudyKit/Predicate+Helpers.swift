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
public typealias Predicate = NSPredicate
#endif

enum CKPredicateError: Error {
    case invalidPredicate(String)
}

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
            // Replace "%@" with objects from the arguments array.
            if index > 0, arguments.count > 0 {
                let argument = argumentsLeft.removeFirst()
                switch argument {
                case is [String]:
                    let stringList = argument as? [String] ?? []
                    let formattedStringList = stringList
                        .map { "\"\($0)\"" }
                        .joined(separator: ", ")
                    substitution += "{ \(formattedStringList) }"
                case is String:
                    substitution += "\"\(argument)\""
                case let date as NSDate:
                    substitution += "CAST(\(date.timeIntervalSinceReferenceDate), \"NSDate\")"
                default:
                    substitution += "\(argument)"
                }
            }
            let keyPathSplits = split.components(separatedBy: "%K")
            // Replace "%K" with field names from the arguments array.
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
    
    func filterBy() throws -> [CKWSFilterDictionary]? {
        guard self.predicateFormat != "TRUEPREDICATE" else {
            return []
        }
        guard self.predicateFormat != "FALSEPREDICATE" else {
            throw CKPredicateError.invalidPredicate(self.predicateFormat)
        }
        
        var filters: [CKWSFilterDictionary] = []
        let (originalComparator, fields) = try self.comparatorWithFields()
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
            } else if field.hasPrefix("CAST("), field.hasSuffix(", \"NSDate\")"), let value = field.components(separatedBy: "CAST(").last?.components(separatedBy: ", \"NSDate\")").first, let timeInterval = Double(value) {
                let date = Date(timeIntervalSinceReferenceDate: timeInterval)
                let timeInterval = date.timeIntervalSince1970
                fieldValue = CKWSRecordFieldValue(value: .dateTime(Int(timeInterval * 1000)), type: nil)
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
            } else if let number = Int(field) {
                fieldValue = CKWSRecordFieldValue(value: .number(number), type: nil)
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
            throw CKPredicateError.invalidPredicate(self.predicateFormat)
        }
        filters.append(CKWSFilterDictionary(comparator: comparator, fieldName: fn, fieldValue: fv))
        return filters
    }
    
    private func comparatorWithFields() throws -> (CKWSFilterDictionary.Comparator, [String]) {
        let doubleEqualsSplits = self.predicateFormat.components(separatedByFirst: "==")
        if doubleEqualsSplits.count == 2 {
            let fields = doubleEqualsSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.equals, fields)
        }
        
        let greaterThanOrEqualsSplits = self.predicateFormat.components(separatedByFirst: ">=")
        if greaterThanOrEqualsSplits.count == 2 {
            let fields = greaterThanOrEqualsSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.greaterThanOrEquals, fields)
        }
    
        let equalsOrGreaterThanSplits = self.predicateFormat.components(separatedByFirst: "=>")
        if equalsOrGreaterThanSplits.count == 2 {
            let fields = equalsOrGreaterThanSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.greaterThanOrEquals, fields)
        }
        
        let lessThanOrEqualsSplits = self.predicateFormat.components(separatedByFirst: "<=")
        if lessThanOrEqualsSplits.count == 2 {
            let fields = lessThanOrEqualsSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.lessThanOrEquals, fields)
        }
        
        let equalsOrLessThanSplits = self.predicateFormat.components(separatedByFirst: "=<")
        if equalsOrLessThanSplits.count == 2 {
            let fields = equalsOrLessThanSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.lessThanOrEquals, fields)
        }
        
        let notEquals = self.predicateFormat.components(separatedByFirst: "!=")
        if notEquals.count == 2 {
            let fields = notEquals.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.notEquals, fields)
        }
        
        let 🥕🥕Splits = self.predicateFormat.components(separatedByFirst: "<>")
        if 🥕🥕Splits.count == 2 {
            let fields = 🥕🥕Splits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.notEquals, fields)
        }
        
        let equalsSplits = self.predicateFormat.components(separatedByFirst: "=")
        if equalsSplits.count == 2 {
           let fields = equalsSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
           return (.equals, fields)
        }
        
        let greaterThanSplits = self.predicateFormat.components(separatedByFirst: ">")
        if greaterThanSplits.count == 2 {
           let fields = greaterThanSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
           return (.greaterThan, fields)
        }
        
        let lessThanSplits = self.predicateFormat.components(separatedByFirst: "<")
        if lessThanSplits.count == 2 {
           let fields = lessThanSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
           return (.lessThan, fields)
        }
        
        let containsSplits = self.predicateFormat.components(separatedByFirst: "CONTAINS")
        if containsSplits.count == 2 {
           let fields = containsSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
           return (.listContains, fields)
        }
        
        let beginsWithSplits = self.predicateFormat.components(separatedByFirst: "BEGINSWITH")
        if beginsWithSplits.count == 2 {
           let fields = beginsWithSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
           return (.beginsWith, fields)
        }
        
        let inSplits = self.predicateFormat.components(separatedByFirst: "IN")
        if inSplits.count == 2 {
            let fields = inSplits.compactMap { String($0).trimmingCharacters(in: .whitespaces) }
            return (.in, fields)
        }

        throw CKPredicateError.invalidPredicate(self.predicateFormat)
    }
    
}
