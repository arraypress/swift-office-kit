//
//  TemplateValue.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  What a placeholder can be filled with: a piece of text, a group of named
//  values (`{{customer.name}}`), or a list of groups — one table row each.
//

import Foundation

/// A value for a template.
public indirect enum TemplateValue: Sendable, Equatable {
    /// Text, as it should appear. A newline becomes a line break.
    case text(String)
    /// Named values, reached with a dot: `{{customer.name}}`.
    case group([String: TemplateValue])
    /// One group per table row: a row whose placeholders start `items.` is
    /// repeated once per entry of `items`.
    case list([[String: TemplateValue]])
}
