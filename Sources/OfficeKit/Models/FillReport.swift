//
//  FillReport.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  What a fill did: how many placeholders it filled, how many of those Word
//  had split across runs, which values it lacked, which it was given and
//  never used, and how many table rows it wrote from lists.
//

import Foundation

/// The outcome of filling a template.
public struct FillReport: Sendable, Codable, Equatable {
    /// Placeholders replaced.
    public var filled: Int = 0
    /// Of those, how many spanned more than one run.
    public var split: Int = 0
    /// Names asked for and not given, left as they were.
    public var missing: [String] = []
    /// Names given and never asked for — usually a typo on one side.
    public var unused: [String] = []
    /// Table rows written from lists — one per entry; an empty list removes
    /// its row and adds none.
    public var repeatedRows: Int = 0

    public init() {}
}
