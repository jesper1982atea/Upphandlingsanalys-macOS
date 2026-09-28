// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ProcurementRAG",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ProcurementRAG", targets: ["ProcurementRAG"]),
        .library(name: "ProcurementRAGCore", targets: ["ProcurementRAGCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.2"),
        .package(url: "https://github.com/youngminz/libxls-swift.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "ProcurementRAGCore",
            dependencies: [
                .product(name: "CoreXLSX", package: "CoreXLSX"),
                .product(name: "LibXLS", package: "libxls-swift")
            ],
            linkerSettings: [
                .linkedFramework("PDFKit")
            ]
        ),
        .executableTarget(
            name: "ProcurementRAG",
            dependencies: ["ProcurementRAGCore"]
        ),
        .testTarget(
            name: "ProcurementRAGTests",
            dependencies: ["ProcurementRAGCore"]
        )
    ]
)
