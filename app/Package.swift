// swift-tools-version: 5.9
// Artifact-Version: 1.0.0
// Release-Date: 2026-09-07
// Stability: Stable
// Change-Summary: Define the native OLK2MBOX interface as a reproducible Swift package.
// SPDX-FileCopyrightText: 2026 igp76
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "OLK2MBOX",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OLK2MBOX", targets: ["OLK2MBOX"])
    ],
    targets: [
        .executableTarget(
            name: "OLK2MBOX",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
