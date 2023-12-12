//
//  Predicate+HelpersTests.swift
//  
//
//  Created by Camden on 12/26/20.
//

import XCTest
#if os(Linux)
import FoundationNetworking
#endif
@testable import CloudyKit

final class PredicatePlusHelpersTests: XCTestCase {
    
    func testFieldContainsSpecificValue() throws {
        let predicates = [
            Predicate(format: "ANY favoriteColors = 'red'"),
            Predicate(format: "favoriteColors CONTAINS 'red'"),
            Predicate(format: "%K CONTAINS %@", "favoriteColors", "red"),
            Predicate(format: "'red' IN favoriteColors"),
        ]
        
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .listContains, fieldName: "favoriteColors", fieldValue: CKWSRecordFieldValue(value: .string("red"), type: nil))
            ], try predicate.filterBy())
        }
    }
    
    func testMatchFieldToSpecificValue() throws {
        let numberPredicate = Predicate(format: "29 = age")
        XCTAssertEqual([CKWSFilterDictionary(comparator: .equals, fieldName: "age", fieldValue: CKWSRecordFieldValue(value: .number(29), type: nil))], try numberPredicate.filterBy())
        
        let date = NSDate(timeIntervalSince1970: 123456789)
        let datePredicate = Predicate(format: "today == %@", date)
        XCTAssertEqual([CKWSFilterDictionary(comparator: .equals, fieldName: "today", fieldValue: CKWSRecordFieldValue(value: .dateTime(Int(date.timeIntervalSince1970 * 1000)), type: nil))], try datePredicate.filterBy())
        
        let stringPredicate = Predicate(format: "'red' = favoriteColor")
        XCTAssertEqual([CKWSFilterDictionary(comparator: .equals, fieldName: "favoriteColor", fieldValue: CKWSRecordFieldValue(value: .string("red"), type: nil))], try stringPredicate.filterBy())

        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let reference = CKRecord.Reference(recordID: recordID, action: .none)
        let referencePredicate = Predicate(format: "employee == %@", reference)
        XCTAssertEqual([CKWSFilterDictionary(comparator: .equals, fieldName: "employee", fieldValue: CKWSRecordFieldValue(value: .reference(CKWSReferenceDictionary(recordName: recordID.recordName, action: "NONE")), type: nil))], try referencePredicate.filterBy())
    }
    
    func testMatchFieldToOneOrMoreValues() throws {
        let predicates = [
            Predicate(format: "ANY { 'red', 'green' } = favoriteColor"),
            Predicate(format: "favoriteColor IN { 'red', 'green' }"),
        ]
        
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .in, fieldName: "favoriteColor", fieldValue: CKWSRecordFieldValue(value: .stringList(["red", "green"]), type: nil))
            ], try predicate.filterBy())
        }
    }
    
    func testMatchFieldThatStartsWithStringValue() throws {
        let predicates = [
            Predicate(format: "ANY favoriteColors BEGINSWITH 'red'"),
            Predicate(format: "ANY favoriteColors BEGINSWITH %@", "red"),
        ]
        
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .beginsWith, fieldName: "favoriteColors", fieldValue: CKWSRecordFieldValue(value: .string("red"), type: nil))
            ], try predicate.filterBy())
        }
    }
    
    func testEqualsComparator() throws {
        let predicates = [
            Predicate(format: "number = 13"),
            Predicate(format: "number == 13"),
        ]
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .equals, fieldName: "number", fieldValue: CKWSRecordFieldValue(value: .number(13), type: nil))
            ], try predicate.filterBy())
        }
    }
    
    func testGreaterThanOrEqualsComparator() throws {
        let predicates = [
            Predicate(format: "number >= 13"),
            Predicate(format: "number => 13"),
        ]
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .greaterThanOrEquals, fieldName: "number", fieldValue: CKWSRecordFieldValue(value: .number(13), type: nil))
            ], try predicate.filterBy())
        }
    }
    
    func testLessThanOrEqualsComparator() throws {
        let predicates = [
            Predicate(format: "number <= 13"),
            Predicate(format: "number =< 13"),
        ]
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .lessThanOrEquals, fieldName: "number", fieldValue: CKWSRecordFieldValue(value: .number(13), type: nil))
            ], try predicate.filterBy())
        }
    }
    
    func testGreaterThanComparator() throws {
        let predicate = Predicate(format: "number > 13")
        XCTAssertEqual([
            CKWSFilterDictionary(comparator: .greaterThan, fieldName: "number", fieldValue: CKWSRecordFieldValue(value: .number(13), type: nil))
        ], try predicate.filterBy())
    }
    
    func testLessThanComparator() {
        let predicate = Predicate(format: "number < 13")
        XCTAssertEqual([
            CKWSFilterDictionary(comparator: .lessThan, fieldName: "number", fieldValue: CKWSRecordFieldValue(value: .number(13), type: nil))
        ], try predicate.filterBy())
    }
    
    func testNotEqualsComparator() throws {
        let predicates = [
            Predicate(format: "number != 13"),
            Predicate(format: "number <> 13"),
        ]
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .notEquals, fieldName: "number", fieldValue: CKWSRecordFieldValue(value: .number(13), type: nil))
            ], try predicate.filterBy())
        }
    }
    
    func testValuePredicates() throws {
        let truePredicate = Predicate(value: true)
        XCTAssertEqual([], try truePredicate.filterBy())
    }
    
    static var allTests = [
        ("testFieldContainsSpecificValue", testFieldContainsSpecificValue),
        ("testMatchFieldToSpecificValue", testMatchFieldToSpecificValue),
        ("testMatchFieldToOneOrMoreValues", testMatchFieldToOneOrMoreValues),
        ("testMatchFieldThatStartsWithStringValue", testMatchFieldThatStartsWithStringValue),
        ("testEqualsComparator", testEqualsComparator),
        ("testGreaterThanOrEqualsComparator", testGreaterThanOrEqualsComparator),
        ("testLessThanOrEqualsComparator", testLessThanOrEqualsComparator),
        ("testLessThanComparator", testLessThanComparator),
        ("testGreaterThanComparator", testGreaterThanComparator),
        ("testNotEqualsComparator", testNotEqualsComparator),
        ("testValuePredicates", testValuePredicates),
    ]
    
}
