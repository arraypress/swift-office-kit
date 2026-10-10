//
//  CellInput.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  What a typed value means, by the rules a spreadsheet uses when you type
//  into a cell: a leading `=` is a formula, a leading apostrophe forces
//  text (so `'00123` keeps its zeros), TRUE/FALSE are booleans, an ISO date
//  is a date, a plain number is a number, and anything else is text.
//

import Foundation

/// Typed text into cell values.
public enum CellInput {

    /// The value typing `text` into a cell means.
    public static func value(_ text: String) -> CellValue {
        if text.isEmpty { return .empty }
        if text.hasPrefix("'") { return .text(String(text.dropFirst())) }
        if text.hasPrefix("="), text.count > 1 { return .formula(String(text.dropFirst())) }
        switch text.uppercased() {
        case "TRUE": return .bool(true)
        case "FALSE": return .bool(false)
        default: break
        }
        if let date = isoDate(text) { return date }
        // A number as a person types it: no grouping, a dot for decimals,
        // and nothing a number would lose — "007" stays text.
        if text.range(of: #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$"#, options: .regularExpression) != nil,
           let number = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) {
            return .number(number)
        }
        return .text(text)
    }

    /// `2026-10-10` as a date, when it is a real one.
    static func isoDate(_ text: String) -> CellValue? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil, parts.count == 3,
              (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              calendar.component(.day, from: date) == parts[2] else { return nil }
        return .date(year: parts[0], month: parts[1], day: parts[2])
    }
}
