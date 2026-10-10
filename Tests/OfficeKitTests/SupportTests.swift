//
//  SupportTests.swift
//  OfficeKitTests
//
//  Created by David Sherlock on 2026.
//
//  The arithmetic with known answers: column letters, Excel's day numbers
//  (with the day that never was), what typing into a cell means.
//

import Foundation
import Testing
@testable import OfficeKit

@Suite("Support")
struct SupportTests {

    @Test("Columns are bijective base 26")
    func columns() throws {
        #expect(CellAddress.letters(1) == "A")
        #expect(CellAddress.letters(26) == "Z")
        #expect(CellAddress.letters(27) == "AA")
        #expect(CellAddress.letters(16_384) == "XFD")
        #expect(try CellAddress("$aa$10") == CellAddress(column: 27, row: 10))
        #expect(throws: OfficeError.self) { try CellAddress("4B") }
        #expect(throws: OfficeError.self) { try CellAddress("XFE1") }
    }

    @Test("Excel's day numbers, including the 29 February 1900 that never was")
    func serials() {
        #expect(DateSerial.serial(year: 1900, month: 1, day: 1) == 1)
        #expect(DateSerial.serial(year: 1900, month: 2, day: 28) == 59)
        #expect(DateSerial.serial(year: 1900, month: 3, day: 1) == 61)
        #expect(DateSerial.serial(year: 2026, month: 10, day: 10) == 46305)
        #expect(DateSerial.date(serial: 46305) == (2026, 10, 10))
        #expect(DateSerial.serial(year: 1904, month: 1, day: 2, uses1904: true) == 1)
    }

    @Test("Typing into a cell means what it means in a spreadsheet")
    func input() {
        #expect(CellInput.value("123") == .number(123))
        #expect(CellInput.value("-1.5") == .number(Decimal(string: "-1.5")!))
        #expect(CellInput.value("007") == .text("007"), "a leading zero is text")
        #expect(CellInput.value("'123") == .text("123"))
        #expect(CellInput.value("=SUM(A1:A3)") == .formula("SUM(A1:A3)"))
        #expect(CellInput.value("true") == .bool(true))
        #expect(CellInput.value("2026-02-30") == .text("2026-02-30"), "not a real date")
        #expect(CellInput.value("2026-10-10") == .date(year: 2026, month: 10, day: 10))
        #expect(CellInput.value("1,000") == .text("1,000"), "grouping is not guessed")
    }

    @Test("Placeholders take spaces and dots; single braces are prose")
    func placeholders() {
        #expect(Placeholders.matches(in: "{{ a.b }} and {{c}} not {d}").map(\.name) == ["a.b", "c"])
        #expect(Placeholders.listName(of: "items.qty") == "items")
        #expect(Placeholders.listName(of: "qty") == nil)
    }

    @Test("Date formats are recognised by id and by code")
    func dateFormats() {
        #expect(NumberFormats.isDate(id: 14, custom: [:]))
        #expect(!NumberFormats.isDate(id: 2, custom: [:]))
        #expect(NumberFormats.isDate(id: 165, custom: [165: "dd/mm/yyyy"]))
        #expect(!NumberFormats.isDate(id: 166, custom: [166: #"0.00" days""#]), "a d inside quotes is not a date")
    }
}
