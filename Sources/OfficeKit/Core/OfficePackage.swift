//
//  OfficePackage.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  A .docx or .xlsx is a zip of XML parts. This holds the parts in memory,
//  in their original order, and writes them back — the parts nobody touched
//  byte for byte, so a template's images, fonts and themes come out exactly
//  as they went in.
//

import Foundation
import ZIPFoundation

/// The parts of an Office Open XML file.
public struct OfficePackage: Sendable {

    /// Every part, in the order the file had them.
    public private(set) var paths: [String]
    private var parts: [String: Data]

    /// Reads a package.
    ///
    /// - Parameter url: A .docx, .xlsx or any OOXML file.
    /// - Throws: ``OfficeError/fileNotFound(_:)`` or ``OfficeError/unreadable(_:)``.
    public init(contentsOf url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OfficeError.fileNotFound(url.path)
        }
        let archive: Archive
        do { archive = try Archive(url: url, accessMode: .read) } catch {
            throw OfficeError.unreadable("\(url.lastPathComponent) is not a zip")
        }
        var paths: [String] = [], parts: [String: Data] = [:]
        do {
            for entry in archive where entry.type == .file {
                var data = Data()
                _ = try archive.extract(entry, skipCRC32: false) { data.append($0) }
                paths.append(entry.path)
                parts[entry.path] = data
            }
        } catch {
            throw OfficeError.unreadable("\(url.lastPathComponent): \(error.localizedDescription)")
        }
        guard parts["[Content_Types].xml"] != nil else {
            throw OfficeError.unreadable("\(url.lastPathComponent) has no [Content_Types].xml")
        }
        self.paths = paths
        self.parts = parts
    }

    /// A part's bytes.
    public func data(_ path: String) -> Data? { parts[path] }

    /// A part parsed as XML, whitespace and all.
    public func xml(_ path: String) throws -> XMLDocument? {
        guard let data = parts[path] else { return nil }
        do { return try XMLDocument(data: data, options: [.nodePreserveAll]) } catch {
            throw OfficeError.unreadable("\(path) is not well-formed XML")
        }
    }

    /// Replaces or adds a part.
    public mutating func set(_ path: String, data: Data) {
        if parts[path] == nil { paths.append(path) }
        parts[path] = data
    }

    /// Replaces a part with an XML document.
    ///
    /// Attributes are written in double quotes, as Word and Excel write
    /// them: preserving quote style kept the file's own, but an attribute
    /// added here came out in single quotes — valid XML, and the only
    /// thing in the file no Office application would have written.
    public mutating func set(_ path: String, xml: XMLDocument) {
        var options: XMLNode.Options = [.nodePreserveAll]
        options.remove(.nodePreserveQuotes)
        options.insert(.nodeUseDoubleQuotes)
        set(path, data: xml.xmlData(options: options))
    }

    /// Drops a part.
    public mutating func remove(_ path: String) {
        parts[path] = nil
        paths.removeAll { $0 == path }
    }

    /// Writes the package, replacing anything at `url`.
    ///
    /// - Throws: ``OfficeError/unwritable(_:)``.
    public func write(to url: URL) throws {
        let staging = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let archive = try Archive(url: staging, accessMode: .create)
            for path in paths {
                guard let data = parts[path] else { continue }
                try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count),
                                     compressionMethod: .deflate) { position, size in
                    data.subdata(in: Int(position)..<Int(position) + size)
                }
            }
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            try FileManager.default.moveItem(at: staging, to: url)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw OfficeError.unwritable("\(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
