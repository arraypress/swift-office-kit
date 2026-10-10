//
//  XMLElement+Office.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  Walking OOXML by qualified name — `w:p`, `w:t`, `c` — which is how the
//  files spell them. Prefixes are fixed by the specification's own parts, so
//  matching the qualified name is exact for the parts this library edits.
//

import Foundation

extension XMLElement {

    /// Child elements with a qualified name.
    func children(named name: String) -> [XMLElement] {
        (children ?? []).compactMap { $0 as? XMLElement }.filter { $0.name == name }
    }

    /// The first child element with a qualified name.
    func child(named name: String) -> XMLElement? {
        (children ?? []).lazy.compactMap { $0 as? XMLElement }.first { $0.name == name }
    }

    /// Descendant elements with a qualified name, in document order, not
    /// descending into elements named `stop` — a text box's paragraphs are
    /// their own paragraphs, not part of the one that anchors them.
    func descendants(named name: String, stoppingAt stop: String? = nil) -> [XMLElement] {
        var found: [XMLElement] = []
        func walk(_ element: XMLElement) {
            for case let child as XMLElement in element.children ?? [] {
                if child.name == name { found.append(child) }
                if let stop, child.name == stop { continue }
                walk(child)
            }
        }
        walk(self)
        return found
    }

    /// An attribute's value.
    func attribute(_ name: String) -> String? { attribute(forName: name)?.stringValue }

    /// Sets an attribute, adding it when absent.
    func set(_ name: String, _ value: String) {
        if let existing = attribute(forName: name) {
            existing.stringValue = value
        } else {
            addAttribute(XMLNode.attribute(withName: name, stringValue: value) as! XMLNode)
        }
    }

    /// An element with a qualified name and optional text.
    static func named(_ name: String, text: String? = nil) -> XMLElement {
        let element = XMLElement(name: name)
        if let text { element.stringValue = text }
        return element
    }
}
