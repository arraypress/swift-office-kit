//
//  CellValue.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  What a spreadsheet cell holds, as data: the same type is written and read
//  back, which is how every write is checked.
//

import Foundation

/// The contents of one cell.
public enum CellValue: Sendable, Equatable, Codable {
    /// A number, kept exact.
    case number(Decimal)
    /// Text.
    case text(String)
    /// TRUE or FALSE.
    case bool(Bool)
    /// A calendar date, stored as Excel's day number with a date format.
    case date(year: Int, month: Int, day: Int)
    /// A formula, without its leading `=`. Its value is worked out by the
    /// spreadsheet when the file is opened.
    case formula(String)
    /// Nothing: writing this clears the cell.
    case empty

    /// The value as a person would type it into the cell.
    public var display: String {
        switch self {
        case .number(let value): return "\(value)"
        case .text(let text): return text
        case .bool(let value): return value ? "TRUE" : "FALSE"
        case .date(let y, let m, let d): return String(format: "%04d-%02d-%02d", y, m, d)
        case .formula(let formula): return "=" + formula
        case .empty: return ""
        }
    }
}
