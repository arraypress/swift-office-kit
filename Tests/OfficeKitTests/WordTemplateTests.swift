//
//  WordTemplateTests.swift
//  OfficeKitTests
//
//  Created by David Sherlock on 2026.
//
//  Filling, checked by reading the written file back the way a reader
//  would: its text, its placeholders, its formatting.
//

import Foundation
import Testing
@testable import OfficeKit

@Suite("Word templates")
struct WordTemplateTests {

    let values: [String: TemplateValue] = [
        "customer": .group(["name": .text("Anna Smith")]),
        "company": .text("ACME Ltd"),
        "link_text": .text("acme.example"),
        "items": .list([["desc": .text("Widget"), "qty": .text("2")],
                        ["desc": .text("Gadget"), "qty": .text("5")],
                        ["desc": .text("Gizmo"), "qty": .text("1")]]),
    ]

    func template() throws -> (URL, URL) {
        let folder = Fixtures.folder()
        let url = folder.appendingPathComponent("template.docx")
        try Fixtures.docx(body: Fixtures.splitParagraph + Fixtures.linkParagraph + Fixtures.itemTable, to: url)
        return (url, folder.appendingPathComponent("out.docx"))
    }

    @Test("A placeholder Word cut across five runs is found, and counted as split")
    func fieldsAcrossRuns() throws {
        let (url, _) = try template()
        let fields = try WordTemplate(contentsOf: url).fields
        let names = fields.map(\.name)
        #expect(names == ["customer.name", "link_text", "items.desc", "items.qty", "company"])
        #expect(fields.first { $0.name == "customer.name" }?.split == 1)
        #expect(fields.first { $0.name == "company" }?.places == ["header"])
        #expect(fields.first { $0.name == "items.qty" }?.repeats == true)
    }

    @Test("A split placeholder is filled in the run it starts in, and the rest of it is cut away")
    func fillsSplit() throws {
        let (url, out) = try template()
        var template = try WordTemplate(contentsOf: url)
        let report = try template.fill(values)
        #expect(report.split == 1)
        try template.write(to: out)
        let text = try WordTemplate(contentsOf: out).text
        #expect(text.contains("Dear Anna Smith,"))
        #expect(!text.contains("{{"))
        #expect(text.contains("Pay at acme.example"), "inside a hyperlink too")
        #expect(text.contains("ACME Ltd"), "and in the header")
    }

    @Test("The value takes the formatting of the run the placeholder starts in")
    func keepsFirstRunFormatting() throws {
        let (url, out) = try template()
        var template = try WordTemplate(contentsOf: url)
        try template.fill(values)
        try template.write(to: out)
        let xml = String(decoding: try OfficePackage(contentsOf: out).data("word/document.xml")!, as: UTF8.self)
        // The bold run held the "n" of the placeholder; it now holds nothing.
        #expect(xml.contains(#"<w:r><w:rPr><w:b/></w:rPr><w:t></w:t></w:r>"#) || xml.contains(#"<w:r><w:rPr><w:b></w:b></w:rPr><w:t></w:t></w:r>"#))
        #expect(xml.contains("<w:t>Anna Smith</w:t>"))
    }

    @Test("A row naming a list repeats once per entry")
    func repeatsRows() throws {
        let (url, out) = try template()
        var template = try WordTemplate(contentsOf: url)
        let report = try template.fill(values)
        #expect(report.repeatedRows == 3, "one row per item")
        try template.write(to: out)
        let text = try WordTemplate(contentsOf: out).text
        for item in ["Widget", "Gadget", "Gizmo"] { #expect(text.contains(item)) }
        #expect(text.components(separatedBy: "\n").contains("5"))
    }

    @Test("An empty list removes the row")
    func emptyList() throws {
        let (url, out) = try template()
        var template = try WordTemplate(contentsOf: url)
        var none = values
        none["items"] = .list([])
        try template.fill(none)
        try template.write(to: out)
        #expect(!(try WordTemplate(contentsOf: out).text.contains("items")))
    }

    @Test("Missing values are all named, and nothing is changed")
    func missing() throws {
        let (url, _) = try template()
        var template = try WordTemplate(contentsOf: url)
        #expect(throws: OfficeError.missingValues(["customer.name", "link_text", "items.desc", "items.qty"])) {
            try template.fill(["company": .text("ACME")])
        }
    }

    @Test("Allowed to be missing, a placeholder is left for later and the check accepts it")
    func allowMissing() throws {
        let (url, out) = try template()
        var template = try WordTemplate(contentsOf: url)
        let report = try template.fill(["company": .text("ACME")], allowMissing: true)
        #expect(report.missing.count == 4)
        try template.write(to: out)
        #expect(try WordTemplate(contentsOf: out).text.contains("{{link_text}}"))
    }

    @Test("Values never asked for are reported, so a typo does not pass silently")
    func unused() throws {
        let (url, _) = try template()
        var template = try WordTemplate(contentsOf: url)
        var extra = values
        extra["custmer"] = .text("typo")
        #expect(try template.fill(extra).unused == ["custmer"])
    }

    @Test("A newline becomes a line break inside the same run")
    func newlines() throws {
        let folder = Fixtures.folder()
        let url = folder.appendingPathComponent("t.docx"), out = folder.appendingPathComponent("o.docx")
        try Fixtures.docx(body: #"<w:p><w:r><w:rPr><w:i/></w:rPr><w:t>To: {{address}} (post)</w:t></w:r></w:p>"#, to: url)
        var template = try WordTemplate(contentsOf: url)
        try template.fill(["address": .text("1 High St\nLeeds"), "company": .text("x")])
        try template.write(to: out)
        let xml = String(decoding: try OfficePackage(contentsOf: out).data("word/document.xml")!, as: UTF8.self)
        #expect(xml.contains("<w:t>To: 1 High St</w:t><w:br"))
        #expect(xml.contains("Leeds (post)</w:t>"))
    }

    @Test("Spaces at the edge of a value survive")
    func spaces() throws {
        let folder = Fixtures.folder()
        let url = folder.appendingPathComponent("t.docx"), out = folder.appendingPathComponent("o.docx")
        try Fixtures.docx(body: #"<w:p><w:r><w:t>[{{a}}]</w:t></w:r></w:p>"#, to: url)
        var template = try WordTemplate(contentsOf: url)
        try template.fill(["a": .text("  x  "), "company": .text("c")])
        try template.write(to: out)
        #expect(try WordTemplate(contentsOf: out).text.contains("[  x  ]"))
    }
}
