//
//  Cell.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  A cell read back: where it is, what it holds, and — for a formula — the
//  value the file last saved for it, which is stale until a spreadsheet
//  recalculates.
//

import Foundation

/// A cell as read from a sheet.
public struct Cell: Sendable, Equatable, Codable {
    /// Its address: `B4`.
    public let reference: String
    /// What it holds.
    public let value: CellValue
    /// For a formula, the result saved with the file, if any.
    public let cached: String?

    public init(reference: String, value: CellValue, cached: String? = nil) {
        self.reference = reference
        self.value = value
        self.cached = cached
    }
}
