//
//  Placeholders.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  `{{ name }}` — double braces, spaces inside allowed, a name of letters,
//  digits, underscores, hyphens and dots. Double rather than single braces
//  because a single brace is ordinary punctuation in a contract or a
//  maths worksheet, and a template language that fires on prose is worse
//  than one that needs two keystrokes more.
//

import Foundation

/// Finds placeholders in text.
public enum Placeholders {

    /// The pattern: `{{`, optional spaces, a name, optional spaces, `}}`.
    static let pattern = try! NSRegularExpression(pattern: #"\{\{\s*([A-Za-z0-9_][A-Za-z0-9_.\-]*)\s*\}\}"#)

    /// One placeholder in a string.
    public struct Match: Equatable, Sendable {
        /// The name inside.
        public let name: String
        /// Where the whole `{{ … }}` sits, in UTF-16 offsets.
        public let range: NSRange
    }

    /// Every placeholder in a string, in order.
    public static func matches(in text: String) -> [Match] {
        let ns = text as NSString
        return pattern.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            Match(name: ns.substring(with: $0.range(at: 1)), range: $0.range)
        }
    }

    /// The list a name belongs to, when it is `list.field`: `items` for
    /// `items.qty`. Nil for a name with no dot.
    public static func listName(of name: String) -> String? {
        guard let dot = name.firstIndex(of: ".") else { return nil }
        return String(name[..<dot])
    }
}
