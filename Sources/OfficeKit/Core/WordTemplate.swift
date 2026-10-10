//
//  WordTemplate.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  A .docx with `{{placeholders}}`, filled. The body, every header and
//  footer, footnotes and endnotes are read paragraph by paragraph across
//  their runs (see ParagraphText for why), a table row whose placeholders
//  name a list is repeated once per entry, and the written copy is opened
//  again and checked before it is kept.
//

import Foundation

/// A Word template.
///
/// ```swift
/// var template = try WordTemplate(contentsOf: invoiceTemplate)
/// template.fields.map(\.name)        // ["customer.name", "items.qty", …]
/// let report = try template.fill([
///     "customer": .group(["name": .text("Anna Smith")]),
///     "items": .list([["qty": .text("2"), "desc": .text("Widget")]]),
/// ])
/// try template.write(to: invoice)    // re-read and checked before it is kept
/// ```
public struct WordTemplate: Sendable {

    private var package: OfficePackage
    private var expectedValues: [String] = []
    /// The values put in during the current fill — what the check looks for.
    private var inserted: [String] = []
    private var leftAlone: Set<String> = []

    /// Reads a template.
    ///
    /// - Throws: ``OfficeError/fileNotFound(_:)`` or ``OfficeError/unreadable(_:)``
    ///   when it is not a Word document.
    public init(contentsOf url: URL) throws {
        package = try OfficePackage(contentsOf: url)
        guard package.data("word/document.xml") != nil else {
            throw OfficeError.unreadable("\(url.lastPathComponent) has no word/document.xml — is it a Word file?")
        }
    }

    /// The parts that hold text, with the name each is reported under.
    var textParts: [(path: String, place: String)] {
        package.paths.compactMap { path in
            if path == "word/document.xml" { return (path, "body") }
            if path.hasPrefix("word/header"), path.hasSuffix(".xml") { return (path, "header") }
            if path.hasPrefix("word/footer"), path.hasSuffix(".xml") { return (path, "footer") }
            if path == "word/footnotes.xml" { return (path, "footnotes") }
            if path == "word/endnotes.xml" { return (path, "endnotes") }
            return nil
        }
    }

    // MARK: - Reading

    /// Every placeholder the template asks for, in order of first appearance.
    public var fields: [TemplateField] {
        get throws {
            var order: [String] = []
            var places: [String: [String]] = [:], counts: [String: Int] = [:], splits: [String: Int] = [:]
            var repeating: Set<String> = []
            for part in textParts {
                guard let root = try package.xml(part.path)?.rootElement() else { continue }
                for row in root.descendants(named: "w:tr") {
                    for paragraph in row.descendants(named: "w:p") {
                        for match in Placeholders.matches(in: ParagraphText(paragraph: paragraph).text)
                        where Placeholders.listName(of: match.name) != nil {
                            repeating.insert(match.name)
                        }
                    }
                }
                for paragraph in root.descendants(named: "w:p") {
                    let text = ParagraphText(paragraph: paragraph)
                    for match in Placeholders.matches(in: text.text) {
                        if counts[match.name] == nil { order.append(match.name) }
                        counts[match.name, default: 0] += 1
                        if !(places[match.name] ?? []).contains(part.place) { places[match.name, default: []].append(part.place) }
                        if text.isSplit(match.range) { splits[match.name, default: 0] += 1 }
                    }
                }
            }
            return order.map { TemplateField(name: $0, places: places[$0] ?? [], count: counts[$0] ?? 0,
                                             repeats: repeating.contains($0), split: splits[$0] ?? 0) }
        }
    }

    /// The document's visible text, paragraph per line — what a reader would see.
    public var text: String {
        get throws {
            try textParts.compactMap { try package.xml($0.path)?.rootElement() }.flatMap { root in
                root.descendants(named: "w:p").map { ParagraphText(paragraph: $0).text }
            }.joined(separator: "\n")
        }
    }

    // MARK: - Filling

    /// Fills the placeholders.
    ///
    /// - Parameters:
    ///   - values: What to fill them with.
    ///   - allowMissing: Leave placeholders the values lack as they are,
    ///     rather than refusing.
    /// - Returns: What was filled, split, missing and unused.
    /// - Throws: ``OfficeError/missingValues(_:)`` naming every missing
    ///   value, before anything is changed.
    @discardableResult
    public mutating func fill(_ values: [String: TemplateValue], allowMissing: Bool = false) throws -> FillReport {
        // Refuse before touching anything.
        let wanted = try fields
        let missing = wanted.map(\.name).filter { name in
            if let list = Placeholders.listName(of: name), ValueLookup.list(list, in: values) != nil { return false }
            return ValueLookup.text(name, in: values) == nil
        }
        if !missing.isEmpty, !allowMissing { throw OfficeError.missingValues(missing) }

        var report = FillReport()
        report.missing = missing
        let used = Set(wanted.map(\.name)).union(wanted.compactMap { Placeholders.listName(of: $0.name) })
        report.unused = ValueLookup.names(in: values).filter { name in
            !used.contains(name) && !used.contains(where: { $0.hasPrefix(name + ".") })
        }.sorted()

        for part in textParts {
            guard let document = try package.xml(part.path), let root = document.rootElement() else { continue }
            report.repeatedRows += repeatRows(in: root, values: values, report: &report)
            for paragraph in root.descendants(named: "w:p") {
                fill(paragraph, values: values, report: &report)
            }
            package.set(part.path, xml: document)
        }
        leftAlone = Set(missing)
        expectedValues = inserted.filter { !$0.isEmpty }
        inserted = []
        return report
    }

    /// Repeats each table row whose placeholders name a list, once per entry.
    private mutating func repeatRows(in root: XMLElement, values: [String: TemplateValue], report: inout FillReport) -> Int {
        var added = 0
        for row in root.descendants(named: "w:tr") {
            let names = row.descendants(named: "w:p").flatMap { Placeholders.matches(in: ParagraphText(paragraph: $0).text) }
                .map(\.name)
            guard let listName = names.compactMap(Placeholders.listName).first(where: {
                ValueLookup.list($0, in: values) != nil
            }), let entries = ValueLookup.list(listName, in: values),
                  let table = row.parent as? XMLElement else { continue }
            let position = row.index
            for (offset, entry) in entries.enumerated() {
                let copy = row.copy() as! XMLElement
                var scoped = values
                for (key, value) in entry { scoped[listName + "." + key] = value }
                for paragraph in copy.descendants(named: "w:p") { fill(paragraph, values: scoped, report: &report) }
                table.insertChild(copy, at: position + offset)
            }
            row.detach()
            added += entries.count
        }
        return added
    }

    /// Fills one paragraph, last placeholder first so offsets hold.
    private mutating func fill(_ paragraph: XMLElement, values: [String: TemplateValue], report: inout FillReport) {
        var text = ParagraphText(paragraph: paragraph)
        for match in Placeholders.matches(in: text.text).reversed() {
            guard let value = ValueLookup.text(match.name, in: values) else { continue }
            if text.isSplit(match.range) { report.split += 1 }
            text.replace(match.range, with: value)
            inserted.append(value)
            report.filled += 1
        }
    }

    // MARK: - Writing

    /// Writes the filled document, then reopens and checks it: the package
    /// opens, every part parses, no placeholder is left but the ones allowed
    /// to be, and every value given is in the text. A copy that fails is
    /// deleted.
    ///
    /// - Throws: ``OfficeError/unwritable(_:)`` or ``OfficeError/unverified(_:)``.
    public func write(to url: URL) throws {
        try package.write(to: url)
        do {
            let reread = try WordTemplate(contentsOf: url)
            try PackageCheck.verify(reread.package)
            let left = try reread.fields.map(\.name).filter { !leftAlone.contains($0) }
            guard left.isEmpty else { throw OfficeError.unverified("still has {{\(left.joined(separator: "}}, {{"))}}") }
            let text = try reread.text
            for value in expectedValues {
                for line in value.components(separatedBy: "\n") where !line.isEmpty && !text.contains(line) {
                    throw OfficeError.unverified("\"\(line.prefix(40))\" is not in the written text")
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            if let failure = error as? OfficeError, case .unverified = failure { throw failure }
            throw OfficeError.unverified(error.localizedDescription)
        }
    }
}
