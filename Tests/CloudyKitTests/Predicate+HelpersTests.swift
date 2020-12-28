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
    
    func testEqualsReference() {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let reference = CKRecord.Reference(recordID: recordID, action: .none)
        let predicate = Predicate(format: "employee == %@", reference)
        let filterBy = predicate.filterBy
        XCTAssertEqual([
            CKWSFilterDictionary(comparator: .equals, fieldName: "employee", fieldValue: CKWSRecordFieldValue(value: .reference(CKWSReferenceDictionary(recordName: recordID.recordName, action: "NONE")), type: nil))
        ], filterBy)
    }
    
    func testMatchFieldToSpecificValue() {
        let predicates = [
            Predicate(format: "ANY favoriteColors = 'red'"),
            Predicate(format: "favoriteColors CONTAINS 'red'"),
            Predicate(format: "%K CONTAINS %@", "favoriteColors", "red"),
            Predicate(format: "'red' IN favoriteColors"),
        ]
        
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .listContains, fieldName: "favoriteColors", fieldValue: CKWSRecordFieldValue(value: .string("red"), type: nil))
            ], predicate.filterBy)
        }
    }
    
    func testMatchFieldToOneOrMoreValues() {
        let predicates = [
            Predicate(format: "ANY { 'red', 'green' } = favoriteColor"),
            Predicate(format: "favoriteColor IN { 'red', 'green' }"),
        ]
        
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .in, fieldName: "favoriteColor", fieldValue: CKWSRecordFieldValue(value: .stringList(["red", "green"]), type: nil))
            ], predicate.filterBy)
        }
    }
    
    func testMatchFieldThatStartsWithStringValue() {
        let predicates = [
            Predicate(format: "ANY favoriteColors BEGINSWITH 'red'"),
            Predicate(format: "ANY favoriteColors BEGINSWITH %@", "red"),
        ]
        
        for predicate in predicates {
            XCTAssertEqual([
                CKWSFilterDictionary(comparator: .beginsWith, fieldName: "favoriteColors", fieldValue: CKWSRecordFieldValue(value: .string("red"), type: nil))
            ], predicate.filterBy)
        }
    }
    
    func testValuePredicates() {
        let truePredicate = Predicate(value: true)
        XCTAssertEqual([], truePredicate.filterBy)
    }
    
    static var allTests = [
        ("testEqualsReference", testEqualsReference),
        ("testMatchFieldToSpecificValue", testMatchFieldToSpecificValue),
        ("testMatchFieldToOneOrMoreValues", testMatchFieldToOneOrMoreValues),
        ("testMatchFieldThatStartsWithStringValue", testMatchFieldThatStartsWithStringValue),
        ("testValuePredicates", testValuePredicates),
    ]
    
}
