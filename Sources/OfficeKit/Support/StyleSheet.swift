//
//  StyleSheet.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  A workbook's style sheet made complete enough to add a date format to.
//  Not every writer produces one: an Apache POI test file written by an
//  early tool has `<styleSheet/>` and nothing in it, and a minimal writer
//  may leave styles.xml out altogether. Excel itself needs a font, two
//  fills (none and gray125), a border and a default cell format before it
//  will read a format added after them.
//

import Foundation

/// Completing a style sheet.
enum StyleSheet {

    /// The order the schema puts a style sheet's children in.
    static let order = ["numFmts", "fonts", "fills", "borders", "cellStyleXfs", "cellXfs",
                        "cellStyles", "dxfs", "tableStyles", "colors", "extLst"]

    /// The defaults Excel expects, by element.
    static let defaults: [String: String] = [
        "fonts": #"<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>"#,
        "fills": #"<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>"#,
        "borders": #"<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>"#,
        "cellStyleXfs": #"<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>"#,
        "cellXfs": #"<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>"#,
    ]

    /// A complete, empty style sheet.
    static let empty = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"/>"#

    /// Adds the parts Excel needs that the style sheet lacks, in schema order.
    static func complete(_ root: XMLElement) throws {
        for name in ["fonts", "fills", "borders", "cellStyleXfs", "cellXfs"] where root.child(named: name) == nil {
            let fragment = try XMLElement(xmlString: defaults[name]!)
            let rank = order.firstIndex(of: name)!
            let later = (root.children ?? []).compactMap { $0 as? XMLElement }.first {
                (order.firstIndex(of: $0.name ?? "") ?? order.count) > rank
            }
            if let later { root.insertChild(fragment, at: later.index) } else { root.addChild(fragment) }
        }
    }
}
