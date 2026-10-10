//
//  NumberFormats.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  Whether a cell's number is a date. A spreadsheet stores a date as a plain
//  number and lets the cell's number format say "show this as a date", so a
//  reader has to look the format up: built-in ids 14–22 and 45–47 are
//  dates and times, and a custom format is one when it has a y or a d
//  outside quotes and brackets.
//

import Foundation

/// Date detection from number formats.
enum NumberFormats {

    /// The built-in format ids that show a date or a time.
    static let builtInDates: Set<Int> = Set(14...22).union(45...47)

    /// Whether a format id, with the workbook's custom codes, shows a date.
    static func isDate(id: Int, custom: [Int: String]) -> Bool {
        if builtInDates.contains(id) { return true }
        guard let code = custom[id] else { return false }
        var stripped = "", inQuotes = false, inBrackets = false
        for character in code {
            switch character {
            case "\"": inQuotes.toggle()
            case "[": inBrackets = true
            case "]": inBrackets = false
            default: if !inQuotes && !inBrackets { stripped.append(character) }
            }
        }
        let lower = stripped.lowercased()
        return lower.contains("y") || lower.contains("d")
    }

    /// The format a date written by this library gets: ISO, unambiguous in
    /// every locale.
    static let isoDateCode = "yyyy-mm-dd"
}
