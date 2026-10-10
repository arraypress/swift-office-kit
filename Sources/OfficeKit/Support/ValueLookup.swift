//
//  ValueLookup.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  Finding `customer.name` in the values: a key spelled with the dot wins
//  (a flat CSV header "customer.name"), then the path through groups.
//

import Foundation

/// Resolves placeholder names against values.
enum ValueLookup {

    /// The text for a name, or nil when the values do not have it.
    static func text(_ name: String, in values: [String: TemplateValue]) -> String? {
        if case .text(let text)? = values[name] { return text }
        var current: TemplateValue = .group(values)
        for part in name.split(separator: ".").map(String.init) {
            guard case .group(let group) = current, let next = group[part] else { return nil }
            current = next
        }
        if case .text(let text) = current { return text }
        return nil
    }

    /// The list a name refers to, if it is one.
    static func list(_ name: String, in values: [String: TemplateValue]) -> [[String: TemplateValue]]? {
        if case .list(let list)? = values[name] { return list }
        return nil
    }

    /// Every name the values can answer, dotted — for reporting which were
    /// never used.
    static func names(in values: [String: TemplateValue], prefix: String = "") -> [String] {
        values.flatMap { key, value -> [String] in
            switch value {
            case .text: return [prefix + key]
            case .group(let group): return names(in: group, prefix: prefix + key + ".")
            case .list: return [prefix + key]
            }
        }
    }
}
