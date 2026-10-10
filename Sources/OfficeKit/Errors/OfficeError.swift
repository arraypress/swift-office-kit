//
//  OfficeError.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  Failures a caller can act on, each naming what was wrong.
//

import Foundation

/// Why a document could not be read, filled or written.
public enum OfficeError: Error, LocalizedError, Sendable, Equatable {
    /// The file is not there.
    case fileNotFound(String)
    /// The file is not the zip of XML a .docx or .xlsx is, or a part is broken.
    case unreadable(String)
    /// The template asks for values the data does not have. Names them all.
    case missingValues([String])
    /// A cell address that is not one: `B4` and `AA10` are, `4B` is not.
    case badReference(String)
    /// The workbook has no sheet by that name or number.
    case noSuchSheet(String)
    /// Writing over this cell would break other cells: it is the first cell
    /// of a shared formula, which the cells below it copy.
    case sharedFormula(String)
    /// The copy was written but failed its own check, and was deleted.
    case unverified(String)
    /// The file could not be written.
    case unwritable(String)

    /// A phrase that reads inside a sentence, for a CLI or a log.
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "no file at \(path)"
        case .unreadable(let why): return "not a readable Office document: \(why)"
        case .missingValues(let names):
            return "the template needs values for \(names.joined(separator: ", "))"
        case .badReference(let text): return "\"\(text)\" is not a cell address like B4"
        case .noSuchSheet(let name): return "the workbook has no sheet \(name)"
        case .sharedFormula(let ref):
            return "\(ref) starts a shared formula the cells after it copy; writing over it would break them"
        case .unverified(let why): return "the written copy failed its check and was deleted: \(why)"
        case .unwritable(let why): return "could not write: \(why)"
        }
    }
}
