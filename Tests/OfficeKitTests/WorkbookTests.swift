//
//  WorkbookTests.swift
//  OfficeKitTests
//
//  Created by David Sherlock on 2026.
//
//  Cells written and read back, and everything not written left as it was.
//

import Foundation
import Testing
@testable import OfficeKit

@Suite("Workbooks")
struct WorkbookTests {

    func book() throws -> (URL, URL) {
        let folder = Fixtures.folder()
        let url = folder.appendingPathComponent("book.xlsx")
        try Fixtures.xlsx(to: url)
        return (url, folder.appendingPathComponent("out.xlsx"))
    }

    @Test("Existing cells read back: shared strings, numbers, formulas")
    func reads() throws {
        let (url, _) = try book()
        let book = try Workbook(contentsOf: url)
        #expect(try book.cell("A3").value == .text("Rent"))
        #expect(try book.cell("B3").value == .number(950))
        let total = try book.cell("B5")
        #expect(total.value == .formula("SUM(B2:B4)"))
        #expect(total.cached == "950")
        #expect(try book.cell("A1", sheet: "Notes").value == .text("untouched"))
        #expect(try book.cell("Z99").value == .empty)
    }

    @Test("Every kind of value is written and reads back the same")
    func roundTrips() throws {
        let (url, out) = try book()
        var book = try Workbook(contentsOf: url)
        let cells: [(String, CellValue)] = [("B2", .number(Decimal(string: "1250.75")!)), ("A2", .text("  Food  ")),
                                            ("C1", .bool(true)), ("C2", .date(year: 2026, month: 10, day: 10)),
                                            ("B6", .formula("B5*2"))]
        try book.set(cells)
        try book.write(to: out)
        let back = try Workbook(contentsOf: out)
        for (reference, value) in cells { #expect(try back.cell(reference).value == value, "\(reference)") }
    }

    @Test("A cell and a row are inserted in order — Excel calls anything else corrupt")
    func order() throws {
        let (url, out) = try book()
        var book = try Workbook(contentsOf: url)
        try book.set([("A2", .text("new row")), ("D1", .number(4)), ("C3", .number(3))])
        try book.write(to: out)
        let xml = String(decoding: try OfficePackage(contentsOf: out).data("xl/worksheets/sheet1.xml")!, as: UTF8.self)
        let rows = xml.components(separatedBy: "<row r=\"").dropFirst().map { $0.prefix { $0 != "\"" } }
        #expect(rows == ["1", "2", "3", "5"])
        #expect(xml.range(of: #"r="B3""#)!.lowerBound < xml.range(of: #"r="C3""#)!.lowerBound)
        #expect(xml.contains(#"<dimension ref="A1:D5"/>"#) || xml.contains(#"<dimension ref="A1:D5"></dimension>"#))
        #expect(!xml.contains("spans="), "a stale span hint is removed")
    }

    @Test("Writing over a styled cell keeps its style; a date clones it with a date format")
    func styles() throws {
        let (url, out) = try book()
        var book = try Workbook(contentsOf: url)
        try book.set([("A1", .text("Line")), ("B1", .date(year: 2026, month: 1, day: 31))])
        try book.write(to: out)
        let sheet = String(decoding: try OfficePackage(contentsOf: out).data("xl/worksheets/sheet1.xml")!, as: UTF8.self)
        #expect(sheet.contains(#"<c r="A1" s="1" t="inlineStr">"#), "bold kept")
        #expect(sheet.contains(#"<c r="B1" s="2">"#), "a new style, cloned from the bold one")
        let styles = String(decoding: try OfficePackage(contentsOf: out).data("xl/styles.xml")!, as: UTF8.self)
        #expect(styles.contains(#"formatCode="yyyy-mm-dd""#))
        #expect(styles.contains(#"<xf numFmtId="164" fontId="1""#), "the clone keeps the bold font")
        #expect(styles.contains(#"<cellXfs count="3">"#))
    }

    @Test("The rest of the workbook is untouched: shared strings, the other sheet, defined names")
    func untouched() throws {
        let (url, out) = try book()
        var book = try Workbook(contentsOf: url)
        try book.set("B2", .number(1))
        try book.write(to: out)
        let before = try OfficePackage(contentsOf: url), after = try OfficePackage(contentsOf: out)
        #expect(before.data("xl/sharedStrings.xml") == after.data("xl/sharedStrings.xml"), "byte for byte")
        #expect(before.data("xl/worksheets/sheet2.xml") == after.data("xl/worksheets/sheet2.xml"))
        let workbook = String(decoding: after.data("xl/workbook.xml")!, as: UTF8.self)
        #expect(workbook.contains("Budget!$B$5"))
    }

    @Test("Formulas recalculate on open, and the stale calculation chain is gone everywhere")
    func recalculation() throws {
        let (url, out) = try book()
        var book = try Workbook(contentsOf: url)
        try book.set("B2", .number(50))
        try book.write(to: out)
        let package = try OfficePackage(contentsOf: out)
        let workbook = String(decoding: package.data("xl/workbook.xml")!, as: UTF8.self)
        #expect(workbook.contains(#"fullCalcOnLoad="1""#))
        #expect(workbook.range(of: "definedNames")!.lowerBound < workbook.range(of: "calcPr")!.lowerBound)
        #expect(package.data("xl/calcChain.xml") == nil)
        #expect(!String(decoding: package.data("xl/_rels/workbook.xml.rels")!, as: UTF8.self).contains("calcChain"))
        #expect(!String(decoding: package.data("[Content_Types].xml")!, as: UTF8.self).contains("calcChain"))
    }

    @Test("Rows are appended after the last row in use")
    func appends() throws {
        let (url, out) = try book()
        var book = try Workbook(contentsOf: url)
        let first = try book.append([[.text("Fuel"), .number(60)], [.text("Phone"), .number(30)]])
        #expect(first == 6)
        try book.write(to: out)
        let back = try Workbook(contentsOf: out)
        #expect(try back.cell("A7").value == .text("Phone"))
        #expect(try back.sheets.first?.lastRow == 7)
    }

    @Test("Clearing a cell removes it")
    func clears() throws {
        let (url, out) = try book()
        var book = try Workbook(contentsOf: url)
        try book.set("B3", .empty)
        try book.write(to: out)
        #expect(try Workbook(contentsOf: out).cell("B3").value == .empty)
    }

    @Test("A sheet is chosen by name or number; an unknown one is refused")
    func sheets() throws {
        let (url, _) = try book()
        let book = try Workbook(contentsOf: url)
        #expect(try book.sheets.map(\.name) == ["Budget", "Notes"])
        #expect(try book.cell("A1", sheet: "2").value == .text("untouched"))
        #expect(throws: OfficeError.noSuchSheet("Nope")) { try book.cell("A1", sheet: "Nope") }
    }

    @Test("A date goes into a workbook whose style sheet is empty, or missing")
    func emptyStyles() throws {
        for styles in ["<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"/>", nil] as [String?] {
            let folder = Fixtures.folder()
            let url = folder.appendingPathComponent("s.xlsx"), out = folder.appendingPathComponent("o.xlsx")
            try Fixtures.xlsx(to: url)
            var package = try OfficePackage(contentsOf: url)
            if let styles { package.set("xl/styles.xml", data: Data(styles.utf8)) } else { package.remove("xl/styles.xml") }
            try package.write(to: url)
            var book = try Workbook(contentsOf: url)
            try book.set("C1", .date(year: 2026, month: 10, day: 10))
            try book.write(to: out)
            #expect(try Workbook(contentsOf: out).cell("C1").value == .date(year: 2026, month: 10, day: 10))
            let written = try OfficePackage(contentsOf: out)
            let xml = String(decoding: written.data("xl/styles.xml")!, as: UTF8.self)
            #expect(xml.range(of: "<numFmts")!.lowerBound < xml.range(of: "<fonts")!.lowerBound, "schema order")
            #expect(xml.contains("gray125"), "the two fills Excel insists on")
            if styles == nil {
                #expect(String(decoding: written.data("[Content_Types].xml")!, as: UTF8.self).contains("/xl/styles.xml"))
            }
        }
    }

    @Test("A shared formula's first cell is refused")
    func sharedFormula() throws {
        let folder = Fixtures.folder()
        let url = folder.appendingPathComponent("s.xlsx")
        try Fixtures.xlsx(to: url)
        var package = try OfficePackage(contentsOf: url)
        let sheet = String(decoding: package.data("xl/worksheets/sheet1.xml")!, as: UTF8.self)
            .replacingOccurrences(of: "<f>SUM(B2:B4)</f>", with: #"<f t="shared" ref="B5:C5" si="0">SUM(B2:B4)</f>"#)
        package.set("xl/worksheets/sheet1.xml", data: Data(sheet.utf8))
        try package.write(to: url)
        var book = try Workbook(contentsOf: url)
        #expect(throws: OfficeError.sharedFormula("B5")) { try book.set("B5", .number(1)) }
    }
}
