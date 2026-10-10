//
//  Fixtures.swift
//  OfficeKitTests
//
//  Created by David Sherlock on 2026.
//
//  Documents built from XML in the shapes Word and Excel write — a
//  placeholder cut across runs by spell-check marks, a revision id and a
//  bold letter; a styled workbook with shared strings, defined names and a
//  calculation chain — so every test knows exactly what went in.
//

import Foundation
import ZIPFoundation

enum Fixtures {

    static func folder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("office-kit-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes a zip of named parts.
    static func zip(_ parts: [(String, String)], to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        let archive = try Archive(url: url, accessMode: .create)
        for (path, text) in parts {
            let data = Data(text.utf8)
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) {
                data.subdata(in: Int($0)..<Int($0) + $1)
            }
        }
    }

    static let w = #"xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships""#

    /// A Word document with the body given, a header holding `{{company}}`,
    /// and the parts Word needs to open it.
    static func docx(body: String, to url: URL) throws {
        try zip([
            ("[Content_Types].xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/></Types>
            """),
            ("_rels/.rels", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
            """),
            ("word/_rels/document.xml.rels", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com" TargetMode="External"/></Relationships>
            """),
            ("word/document.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:document \(w)><w:body>\(body)<w:sectPr><w:headerReference w:type="default" r:id="rId1"/></w:sectPr></w:body></w:document>
            """),
            ("word/header1.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <w:hdr \(w)><w:p><w:r><w:t>{{company}}</w:t></w:r></w:p></w:hdr>
            """),
        ], to: url)
    }

    /// A paragraph whose `{{customer.name}}` is cut the ways Word cuts it:
    /// a spell-check boundary, a revision id, and a bold "n".
    static let splitParagraph = """
    <w:p><w:r w:rsidR="00A1"><w:t xml:space="preserve">Dear </w:t></w:r><w:r w:rsidR="00A1"><w:t>{{</w:t></w:r><w:proofErr w:type="spellStart"/><w:r w:rsidR="00B2"><w:t>customer.</w:t></w:r><w:r><w:rPr><w:b/></w:rPr><w:t>n</w:t></w:r><w:r w:rsidR="00B2"><w:t>ame</w:t></w:r><w:proofErr w:type="spellEnd"/><w:r><w:t>}},</w:t></w:r></w:p>
    """

    /// A paragraph with a placeholder inside a hyperlink.
    static let linkParagraph = """
    <w:p><w:hyperlink r:id="rId2"><w:r><w:t>Pay at {{link_text}}</w:t></w:r></w:hyperlink></w:p>
    """

    /// A table: a header row, and one row that repeats per item.
    static let itemTable = """
    <w:tbl><w:tr><w:tc><w:p><w:r><w:t>Item</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Qty</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>{{items.desc}}</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>{{ items.qty }}</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
    """

    /// A workbook: one styled sheet with shared strings, a second sheet, a
    /// defined name and a calculation chain.
    static func xlsx(to url: URL) throws {
        try zip([
            ("[Content_Types].xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/><Override PartName="/xl/calcChain.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.calcChain+xml"/></Types>
            """),
            ("_rels/.rels", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
            """),
            ("xl/workbook.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><workbookPr/><sheets><sheet name="Budget" sheetId="1" r:id="rId1"/><sheet name="Notes" sheetId="2" r:id="rId2"/></sheets><definedNames><definedName name="Total">Budget!$B$5</definedName></definedNames></workbook>
            """),
            ("xl/_rels/workbook.xml.rels", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/><Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/calcChain" Target="calcChain.xml"/></Relationships>
            """),
            ("xl/worksheets/sheet1.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:B5"/><sheetData><row r="1" spans="1:2"><c r="A1" s="1" t="s"><v>0</v></c><c r="B1" s="1" t="s"><v>1</v></c></row><row r="3"><c r="A3" t="s"><v>2</v></c><c r="B3"><v>950</v></c></row><row r="5"><c r="A5" s="1" t="s"><v>3</v></c><c r="B5" s="1"><f>SUM(B2:B4)</f><v>950</v></c></row></sheetData></worksheet>
            """),
            ("xl/worksheets/sheet2.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>untouched</t></is></c></row></sheetData></worksheet>
            """),
            ("xl/styles.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/></font><font><b/><sz val="11"/></font></fonts><fills count="1"><fill><patternFill patternType="none"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs></styleSheet>
            """),
            ("xl/sharedStrings.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="4" uniqueCount="4"><si><t>Item</t></si><si><t>Amount</t></si><si><t>Rent</t></si><si><t>Total</t></si></sst>
            """),
            ("xl/calcChain.xml", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <calcChain xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><c r="B5" i="1"/></calcChain>
            """),
        ], to: url)
    }
}
