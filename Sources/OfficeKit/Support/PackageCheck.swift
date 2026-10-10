//
//  PackageCheck.swift
//  OfficeKit
//
//  Created by David Sherlock on 2026.
//
//  The checks every written file passes before it is kept: it opens as a
//  zip, it declares its content types, and every XML part in it parses.
//

import Foundation

/// Structural checks on a package.
enum PackageCheck {

    /// Throws ``OfficeError/unverified(_:)`` naming the first part that fails.
    static func verify(_ package: OfficePackage) throws {
        guard let types = package.data("[Content_Types].xml"),
              (try? XMLDocument(data: types)) != nil else {
            throw OfficeError.unverified("[Content_Types].xml is missing or broken")
        }
        for path in package.paths where path.hasSuffix(".xml") || path.hasSuffix(".rels") {
            guard let data = package.data(path), (try? XMLDocument(data: data)) != nil else {
                throw OfficeError.unverified("\(path) does not parse")
            }
        }
    }
}
