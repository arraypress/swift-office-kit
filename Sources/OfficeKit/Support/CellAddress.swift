//
//  CellAddress.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  `B4` to column 2, row 4 and back. Columns are bijective base 26 — there
//  is no zero, so Z is 26 and AA is 27 — the arithmetic everyone gets wrong
//  once.
//

import Foundation

/// A cell's position.
public struct CellAddress: Sendable, Equatable, Hashable, Comparable {
    /// The column, from 1 (A).
    public let column: Int
    /// The row, from 1.
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    /// Parses `B4`, `aa10`, `$C$7`.
    ///
    /// - Throws: ``OfficeError/badReference(_:)``.
    public init(_ text: String) throws {
        let cleaned = text.replacingOccurrences(of: "$", with: "").uppercased()
        let letters = cleaned.prefix { $0.isLetter }
        let digits = cleaned.dropFirst(letters.count)
        guard !letters.isEmpty, letters.count <= 3, let row = Int(digits), row >= 1, row <= 1_048_576,
              letters.allSatisfy({ ("A"..."Z").contains($0) }) else {
            throw OfficeError.badReference(text)
        }
        let column = letters.reduce(0) { $0 * 26 + Int($1.asciiValue! - 64) }
        guard column <= 16_384 else { throw OfficeError.badReference(text) }
        self.column = column
        self.row = row
    }

    /// The column's letters: 1 → A, 27 → AA.
    public static func letters(_ column: Int) -> String {
        var number = column, out = ""
        while number > 0 {
            let remainder = (number - 1) % 26
            out = String(UnicodeScalar(UInt8(65 + remainder))) + out
            number = (number - 1) / 26
        }
        return out
    }

    /// `B4`.
    public var reference: String { Self.letters(column) + "\(row)" }

    public static func < (lhs: CellAddress, rhs: CellAddress) -> Bool {
        (lhs.row, lhs.column) < (rhs.row, rhs.column)
    }
}
