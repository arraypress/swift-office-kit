//
//  TemplateField.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  One placeholder a template asks for, and where — so a caller can see what
//  a template needs before filling it.
//

import Foundation

/// A placeholder found in a template.
public struct TemplateField: Sendable, Codable, Equatable, Hashable {
    /// The name inside the braces: `customer.name`.
    public let name: String
    /// The parts it appears in: "body", "header", "footer", "footnotes", "endnotes".
    public let places: [String]
    /// How many times it appears.
    public let count: Int
    /// Whether it sits in a table row that repeats per list entry.
    public let repeats: Bool
    /// How many of its appearances Word had split across formatting runs —
    /// the ones a plain find-and-replace would have missed.
    public let split: Int

    public init(name: String, places: [String], count: Int, repeats: Bool, split: Int) {
        self.name = name
        self.places = places
        self.count = count
        self.repeats = repeats
        self.split = split
    }
}
