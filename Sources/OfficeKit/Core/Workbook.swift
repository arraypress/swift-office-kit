//
//  Workbook.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  Cells written into an existing .xlsx without disturbing anything else in
//  it: styles, other sheets, shared strings, defined names, charts. Cells
//  are inserted in row and column order (Excel calls a file with them out
//  of order corrupt), text is written inline so the shared-string table is
//  never rewritten, a date borrows the cell's own style with a date format
//  added, and the workbook is told to recalculate when it opens — formula
//  results saved in the file are stale the moment any cell changes.
//

import Foundation

/// An Excel workbook.
///
/// ```swift
/// var book = try Workbook(contentsOf: budget)
/// try book.set("B4", .number(1250))
/// try book.set("B5", .formula("SUM(B1:B4)"))
/// try book.append([[.date(year: 2026, month: 10, day: 10), .text("Rent"), .number(-950)]])
/// try book.write(to: updated)      // every cell written is read back first
/// ```
public struct Workbook: Sendable {

    private var package: OfficePackage
    private struct Sheet: Sendable { let name: String; let path: String }
    private var sheetList: [Sheet] = []
    private var sharedStrings: [String] = []
    private var uses1904 = false
    private var formatOfStyle: [Int] = []
    private var customFormats: [Int: String] = [:]
    private var dateStyleFor: [Int: Int] = [:]
    /// Cells written, for the read-back check.
    private var written: [(sheet: String, reference: String, value: CellValue)] = []

    /// Reads a workbook.
    ///
    /// - Throws: ``OfficeError/fileNotFound(_:)`` or ``OfficeError/unreadable(_:)``.
    public init(contentsOf url: URL) throws {
        package = try OfficePackage(contentsOf: url)
        guard let workbook = try package.xml("xl/workbook.xml")?.rootElement() else {
            throw OfficeError.unreadable("\(url.lastPathComponent) has no xl/workbook.xml — is it an Excel file?")
        }
        uses1904 = workbook.child(named: "workbookPr")?.attribute("date1904").map { $0 == "1" || $0 == "true" } ?? false
        let relationships = try package.xml("xl/_rels/workbook.xml.rels")?.rootElement()?.children(named: "Relationship") ?? []
        var targets: [String: String] = [:]
        for relationship in relationships {
            if let id = relationship.attribute("Id"), let target = relationship.attribute("Target") {
                targets[id] = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/" + target
            }
        }
        for sheet in workbook.child(named: "sheets")?.children(named: "sheet") ?? [] {
            guard let name = sheet.attribute("name"), let id = sheet.attribute("r:id"), let path = targets[id] else { continue }
            sheetList.append(Sheet(name: name, path: path))
        }
        guard !sheetList.isEmpty else { throw OfficeError.unreadable("\(url.lastPathComponent) lists no sheets") }
        try loadSharedStrings()
        try loadStyles()
    }

    private mutating func loadSharedStrings() throws {
        guard let root = try package.xml("xl/sharedStrings.xml")?.rootElement() else { return }
        sharedStrings = root.children(named: "si").map { item in
            item.descendants(named: "t", stoppingAt: "rPh").map { $0.stringValue ?? "" }.joined()
        }
    }

    private mutating func loadStyles() throws {
        guard let root = try package.xml("xl/styles.xml")?.rootElement() else { return }
        for format in root.child(named: "numFmts")?.children(named: "numFmt") ?? [] {
            if let id = format.attribute("numFmtId").flatMap(Int.init), let code = format.attribute("formatCode") {
                customFormats[id] = code
            }
        }
        formatOfStyle = (root.child(named: "cellXfs")?.children(named: "xf") ?? []).map {
            $0.attribute("numFmtId").flatMap(Int.init) ?? 0
        }
    }

    // MARK: - Sheets

    /// The sheets, in tab order.
    public var sheets: [SheetInfo] {
        get throws {
            try sheetList.enumerated().map { index, sheet in
                let root = try package.xml(sheet.path)?.rootElement()
                let rows = root?.child(named: "sheetData")?.children(named: "row") ?? []
                let last = rows.compactMap { $0.attribute("r").flatMap(Int.init) }.max() ?? 0
                return SheetInfo(name: sheet.name, index: index + 1,
                                 range: root?.child(named: "dimension")?.attribute("ref"), lastRow: last)
            }
        }
    }

    /// A sheet by name (any case) or position ("2"); the first when nil.
    private func sheet(_ name: String?) throws -> Sheet {
        guard let name else { return sheetList[0] }
        if let match = sheetList.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return match }
        if let index = Int(name), (1...sheetList.count).contains(index) { return sheetList[index - 1] }
        throw OfficeError.noSuchSheet(name)
    }

    // MARK: - Reading

    /// One cell.
    public func cell(_ reference: String, sheet name: String? = nil) throws -> Cell {
        let address = try CellAddress(reference)
        let sheet = try sheet(name)
        guard let root = try package.xml(sheet.path)?.rootElement(),
              let row = root.child(named: "sheetData")?.children(named: "row").first(where: { $0.attribute("r") == "\(address.row)" }),
              let element = row.children(named: "c").first(where: { $0.attribute("r")?.uppercased() == address.reference })
        else { return Cell(reference: address.reference, value: .empty) }
        return read(element, at: address.reference)
    }

    /// A rectangle of cells, row by row: `A1:C5`.
    public func cells(_ range: String, sheet name: String? = nil) throws -> [[Cell]] {
        let ends = range.split(separator: ":").map(String.init)
        let from = try CellAddress(ends[0]), to = try CellAddress(ends.count > 1 ? ends[1] : ends[0])
        return try (min(from.row, to.row)...max(from.row, to.row)).map { row in
            try (min(from.column, to.column)...max(from.column, to.column)).map { column in
                try cell(CellAddress(column: column, row: row).reference, sheet: name)
            }
        }
    }

    private func read(_ element: XMLElement, at reference: String) -> Cell {
        let raw = element.child(named: "v")?.stringValue
        if let formula = element.child(named: "f")?.stringValue, !formula.isEmpty {
            return Cell(reference: reference, value: .formula(formula), cached: raw)
        }
        switch element.attribute("t") {
        case "s":
            let text = raw.flatMap(Int.init).flatMap { $0 < sharedStrings.count ? sharedStrings[$0] : nil } ?? ""
            return Cell(reference: reference, value: .text(text))
        case "inlineStr":
            let text = element.child(named: "is")?.descendants(named: "t", stoppingAt: "rPh").map { $0.stringValue ?? "" }.joined() ?? ""
            return Cell(reference: reference, value: .text(text))
        case "b": return Cell(reference: reference, value: .bool(raw == "1"))
        case "str", "e": return Cell(reference: reference, value: .text(raw ?? ""))
        default:
            guard let raw, let number = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else {
                return Cell(reference: reference, value: .empty)
            }
            let style = element.attribute("s").flatMap(Int.init) ?? 0
            if style < formatOfStyle.count, NumberFormats.isDate(id: formatOfStyle[style], custom: customFormats),
               let serial = Int(raw) {
                let date = DateSerial.date(serial: serial, uses1904: uses1904)
                return Cell(reference: reference, value: .date(year: date.year, month: date.month, day: date.day))
            }
            return Cell(reference: reference, value: .number(number))
        }
    }

    // MARK: - Writing

    /// Whether the workbook is set to calculate only when asked (F9).
    ///
    /// Such a workbook keeps its new formulas — and, in LibreOffice, its
    /// booleans, which it imports as `=TRUE()` — at 0 until someone
    /// recalculates, whatever `fullCalcOnLoad` says. MEASURED: of 40 real
    /// workbooks written and opened in LibreOffice 26.8, 39 computed the new
    /// formula on open; the one that did not (Apache POI's 47504) is set to
    /// manual. Its mode is the owner's choice, so it is reported, not changed.
    public var calculatesManually: Bool {
        guard let document = try? package.xml("xl/workbook.xml"),
              let calc = document.rootElement()?.child(named: "calcPr") else { return false }
        return calc.attribute("calcMode") == "manual"
    }

    /// Writes one cell.
    ///
    /// - Throws: ``OfficeError/badReference(_:)``, ``OfficeError/noSuchSheet(_:)``,
    ///   or ``OfficeError/sharedFormula(_:)`` when the cell starts a shared
    ///   formula other cells copy.
    public mutating func set(_ reference: String, _ value: CellValue, sheet name: String? = nil) throws {
        try set([(reference, value)], sheet: name)
    }

    /// Writes several cells in one pass over the sheet.
    ///
    /// The sheet is parsed once and written once however many cells change —
    /// appending a thousand rows one cell at a time would otherwise parse it
    /// a thousand times.
    public mutating func set(_ cells: [(String, CellValue)], sheet name: String? = nil) throws {
        let sheet = try sheet(name)
        let addressed = try cells.map { (try CellAddress($0.0), $0.1) }
        guard let document = try package.xml(sheet.path), let root = document.rootElement(),
              let data = root.child(named: "sheetData") else {
            throw OfficeError.unreadable("\(sheet.path) has no sheetData")
        }
        for (address, value) in addressed {
            let row = rowElement(address.row, in: data)
            row.removeAttribute(forName: "spans")   // an optional hint, wrong once a cell is added
            let cell = cellElement(address, in: row)
            if let formula = cell.child(named: "f"), formula.attribute("t") == "shared", formula.attribute("ref") != nil {
                throw OfficeError.sharedFormula(address.reference)
            }
            if case .empty = value {
                cell.detach()
            } else {
                try write(value, into: cell)
            }
            written.append((sheet.name, address.reference, value))
        }
        updateDimension(root)
        package.set(sheet.path, xml: document)
    }

    /// Adds rows after the last row in use.
    ///
    /// - Parameters:
    ///   - rows: The values, row by row, from column A (or `column`).
    ///   - name: The sheet.
    ///   - column: The first column, from 1.
    /// - Returns: The number of the first row written.
    @discardableResult
    public mutating func append(_ rows: [[CellValue]], sheet name: String? = nil, column: Int = 1) throws -> Int {
        let target = try sheet(name)
        let start = (try sheets.first { $0.name == target.name }?.lastRow ?? 0) + 1
        var cells: [(String, CellValue)] = []
        for (offset, values) in rows.enumerated() {
            for (index, value) in values.enumerated() {
                if case .empty = value { continue }
                cells.append((CellAddress(column: column + index, row: start + offset).reference, value))
            }
        }
        try set(cells, sheet: target.name)
        return start
    }

    /// The `row` element for a row number, made and placed in order if absent.
    private func rowElement(_ number: Int, in data: XMLElement) -> XMLElement {
        let rows = data.children(named: "row")
        if let existing = rows.first(where: { $0.attribute("r") == "\(number)" }) { return existing }
        let row = XMLElement.named("row")
        row.set("r", "\(number)")
        if let after = rows.first(where: { ($0.attribute("r").flatMap(Int.init) ?? 0) > number }) {
            data.insertChild(row, at: after.index)
        } else {
            data.addChild(row)
        }
        return row
    }

    /// The `c` element for an address, made and placed in column order if absent.
    private func cellElement(_ address: CellAddress, in row: XMLElement) -> XMLElement {
        let cells = row.children(named: "c")
        if let existing = cells.first(where: { $0.attribute("r")?.uppercased() == address.reference }) { return existing }
        let cell = XMLElement.named("c")
        cell.set("r", address.reference)
        if let after = cells.first(where: { (try? CellAddress($0.attribute("r") ?? ""))?.column ?? 0 > address.column }) {
            row.insertChild(cell, at: after.index)
        } else {
            row.addChild(cell)
        }
        return cell
    }

    private mutating func write(_ value: CellValue, into cell: XMLElement) throws {
        cell.setChildren(nil)
        cell.removeAttribute(forName: "t")
        switch value {
        case .number(let number):
            cell.addChild(XMLElement.named("v", text: "\(number)"))
        case .text(let text):
            cell.set("t", "inlineStr")
            let inline = XMLElement.named("is")
            let node = XMLElement.named("t", text: text)
            if text.first == " " || text.last == " " || text.contains("\n") { node.set("xml:space", "preserve") }
            inline.addChild(node)
            cell.addChild(inline)
        case .bool(let flag):
            cell.set("t", "b")
            cell.addChild(XMLElement.named("v", text: flag ? "1" : "0"))
        case .date(let year, let month, let day):
            let style = cell.attribute("s").flatMap(Int.init) ?? 0
            if !(style < formatOfStyle.count && NumberFormats.isDate(id: formatOfStyle[style], custom: customFormats)) {
                cell.set("s", "\(try dateStyle(basedOn: style))")
            }
            cell.addChild(XMLElement.named("v", text: "\(DateSerial.serial(year: year, month: month, day: day, uses1904: uses1904))"))
        case .formula(let formula):
            cell.addChild(XMLElement.named("f", text: formula.hasPrefix("=") ? String(formula.dropFirst()) : formula))
        case .empty:
            break
        }
    }

    /// A cell style like `base` but showing an ISO date, added once per base.
    private mutating func dateStyle(basedOn base: Int) throws -> Int {
        if let known = dateStyleFor[base] { return known }
        if package.data("xl/styles.xml") == nil { try addStyleSheet() }
        guard let document = try package.xml("xl/styles.xml"), let root = document.rootElement() else {
            throw OfficeError.unreadable("xl/styles.xml has no style sheet")
        }
        try StyleSheet.complete(root)
        guard let xfs = root.child(named: "cellXfs") else { throw OfficeError.unreadable("xl/styles.xml has no cellXfs") }
        // A completed sheet may have gained its first formats just now.
        formatOfStyle = xfs.children(named: "xf").map { $0.attribute("numFmtId").flatMap(Int.init) ?? 0 }
        var formats = root.child(named: "numFmts")
        if formats == nil {
            let made = XMLElement.named("numFmts")
            root.insertChild(made, at: 0)
            formats = made
        }
        let existing = formats!.children(named: "numFmt")
        let id: Int
        if let match = existing.first(where: { $0.attribute("formatCode") == NumberFormats.isoDateCode }),
           let known = match.attribute("numFmtId").flatMap(Int.init) {
            id = known
        } else {
            id = max(163, existing.compactMap { $0.attribute("numFmtId").flatMap(Int.init) }.max() ?? 163) + 1
            let format = XMLElement.named("numFmt")
            format.set("numFmtId", "\(id)")
            format.set("formatCode", NumberFormats.isoDateCode)
            formats!.addChild(format)
            customFormats[id] = NumberFormats.isoDateCode
        }
        formats!.set("count", "\(formats!.children(named: "numFmt").count)")

        let styles = xfs.children(named: "xf")
        let copy = (base < styles.count ? styles[base].copy() : XMLElement.named("xf")) as! XMLElement
        copy.set("numFmtId", "\(id)")
        copy.set("applyNumberFormat", "1")
        xfs.addChild(copy)
        xfs.set("count", "\(styles.count + 1)")
        package.set("xl/styles.xml", xml: document)
        formatOfStyle.append(id)
        dateStyleFor[base] = styles.count
        return styles.count
    }

    /// Adds a style sheet to a workbook that has none: the part, its
    /// relationship, and its content type.
    private mutating func addStyleSheet() throws {
        package.set("xl/styles.xml", data: Data(StyleSheet.empty.utf8))
        if let document = try package.xml("xl/_rels/workbook.xml.rels"), let root = document.rootElement() {
            let ids = root.children(named: "Relationship").compactMap { $0.attribute("Id") }
            var number = ids.count + 1
            while ids.contains("rId\(number)") { number += 1 }
            let relationship = XMLElement.named("Relationship")
            relationship.set("Id", "rId\(number)")
            relationship.set("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles")
            relationship.set("Target", "styles.xml")
            root.addChild(relationship)
            package.set("xl/_rels/workbook.xml.rels", xml: document)
        }
        if let document = try package.xml("[Content_Types].xml"), let root = document.rootElement() {
            let override = XMLElement.named("Override")
            override.set("PartName", "/xl/styles.xml")
            override.set("ContentType", "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml")
            root.addChild(override)
            package.set("[Content_Types].xml", xml: document)
        }
    }

    /// Sets `<dimension ref>` to the rectangle the cells now occupy.
    private func updateDimension(_ root: XMLElement) {
        let addresses = (root.child(named: "sheetData")?.children(named: "row") ?? [])
            .flatMap { $0.children(named: "c") }.compactMap { try? CellAddress($0.attribute("r") ?? "") }
        guard let dimension = root.child(named: "dimension"), !addresses.isEmpty else { return }
        let top = CellAddress(column: addresses.map(\.column).min()!, row: addresses.map(\.row).min()!)
        let bottom = CellAddress(column: addresses.map(\.column).max()!, row: addresses.map(\.row).max()!)
        dimension.set("ref", top == bottom ? top.reference : "\(top.reference):\(bottom.reference)")
    }

    // MARK: - Saving

    /// Writes the workbook, then reopens it and reads back every cell that
    /// was written; a copy that does not read back as written is deleted.
    ///
    /// The workbook is marked to recalculate fully when it next opens, and
    /// its calculation chain — Excel's cache of formula order — is dropped
    /// for Excel to rebuild: a stale chain is what makes Excel offer to
    /// "repair" a file.
    ///
    /// - Throws: ``OfficeError/unwritable(_:)`` or ``OfficeError/unverified(_:)``.
    public mutating func write(to url: URL) throws {
        if !written.isEmpty {
            try markForRecalculation()
            dropCalculationChain()
        }
        try package.write(to: url)
        do {
            let reread = try Workbook(contentsOf: url)
            try PackageCheck.verify(reread.package)
            var latest: [String: CellValue] = [:]
            for entry in written { latest["\(entry.sheet)!\(entry.reference)"] = entry.value }
            for (key, value) in latest {
                let parts = key.split(separator: "!", maxSplits: 1).map(String.init)
                let back = try reread.cell(parts[1], sheet: parts[0]).value
                guard back == normalised(value) else {
                    throw OfficeError.unverified("\(parts[0])!\(parts[1]) reads back as \(back.display), not \(value.display)")
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            if let failure = error as? OfficeError, case .unverified = failure { throw failure }
            throw OfficeError.unverified(error.localizedDescription)
        }
    }

    /// A value as it reads back: a formula without its `=`.
    private func normalised(_ value: CellValue) -> CellValue {
        if case .formula(let formula) = value, formula.hasPrefix("=") { return .formula(String(formula.dropFirst())) }
        return value
    }

    private mutating func markForRecalculation() throws {
        guard let document = try package.xml("xl/workbook.xml"), let root = document.rootElement() else { return }
        var calc = root.child(named: "calcPr")
        if calc == nil {
            // calcPr follows sheets, functionGroups, externalReferences and
            // definedNames in the schema's order, and precedes the rest.
            let made = XMLElement.named("calcPr")
            let anchors = ["definedNames", "externalReferences", "functionGroups", "sheets"]
            let after = anchors.lazy.compactMap { root.child(named: $0) }.first
            root.insertChild(made, at: (after?.index ?? (root.childCount - 1)) + 1)
            calc = made
        }
        calc!.set("fullCalcOnLoad", "1")
        package.set("xl/workbook.xml", xml: document)
    }

    private mutating func dropCalculationChain() {
        guard package.data("xl/calcChain.xml") != nil else { return }
        package.remove("xl/calcChain.xml")
        if let document = try? package.xml("xl/_rels/workbook.xml.rels"), let root = document.rootElement() {
            for relationship in root.children(named: "Relationship") where (relationship.attribute("Type") ?? "").hasSuffix("/calcChain") {
                relationship.detach()
            }
            package.set("xl/_rels/workbook.xml.rels", xml: document)
        }
        if let document = try? package.xml("[Content_Types].xml"), let root = document.rootElement() {
            for override in root.children(named: "Override") where override.attribute("PartName") == "/xl/calcChain.xml" {
                override.detach()
            }
            package.set("[Content_Types].xml", xml: document)
        }
    }
}
