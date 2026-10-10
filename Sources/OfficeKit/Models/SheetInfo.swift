//
//  SheetInfo.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One sheet of a workbook.
public struct SheetInfo: Sendable, Equatable, Codable {
    /// Its name, as on the tab.
    public let name: String
    /// Its position, from 1.
    public let index: Int
    /// The rectangle its cells occupy, `A1:D20`, or nil when empty.
    public let range: String?
    /// The highest row number in use.
    public let lastRow: Int

    public init(name: String, index: Int, range: String?, lastRow: Int) {
        self.name = name
        self.index = index
        self.range = range
        self.lastRow = lastRow
    }
}
