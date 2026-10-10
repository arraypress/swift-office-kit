// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-office-kit",
    // macOS only: the XML is Foundation's XMLDocument, which iOS lacks, and
    // a template is filled from a terminal far more often than from a phone.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "OfficeKit", targets: ["OfficeKit"]),
    ],
    dependencies: [
        // Reading and writing the zip a .docx and an .xlsx are. Already in the
        // fleet through CoreXLSX (peek); two hand-rolled writers exist
        // (text-docx, deck-kit) but neither reads, and this has to do both.
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(name: "OfficeKit", dependencies: ["ZIPFoundation"]),
        .testTarget(name: "OfficeKitTests", dependencies: ["OfficeKit", "ZIPFoundation"]),
    ]
)
