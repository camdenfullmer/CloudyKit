//
//  CKDatabase+Async.swift
//
//
//  Created by Diego Trevisan on 12.12.23.
//

extension CKDatabase {
    public func save(_ record: CKRecord) async throws -> CKRecord? {
        try await withCheckedThrowingContinuation { continuation in
            save(record) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: record)
                }
            }
        }
    }

    public func fetch(withRecordID recordID: CKRecord.ID) async throws -> CKRecord? {
        try await withCheckedThrowingContinuation { continuation in
            fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: record)
                }
            }
        }
    }

    public func delete(withRecordID recordID: CKRecord.ID) async throws -> CKRecord.ID? {
        try await withCheckedThrowingContinuation { continuation in
            delete(withRecordID: recordID) { recordID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: recordID)
                }
            }
        }
    }

    public func perform(_ query: CKQuery, inZoneWith zoneID: CKRecordZone.ID?) async throws -> [CKRecord]? {
        try await withCheckedThrowingContinuation { continuation in
            perform(query, inZoneWith: zoneID) { records, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: records)
                }
            }
        }
    }
}
