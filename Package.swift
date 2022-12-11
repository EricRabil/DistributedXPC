// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

//-F/System/Library/PrivateFrameworks -framework IDS -Wl,-U,_OBJC_CLASS_$_IDSInternalQueueController -Wl,-U,_OBJC_CLASS_$__IDSAccount -Wl,-U,_OBJC_CLASS_$__IDSService -Wl,-U,_OBJC_CLASS_$__IDSConnection -Wl,-U,_OBJC_CLASS_$__IDSSession

func weakClass(_ name: String) -> String {
    "-Wl,-U,_OBJC_CLASS_$_\(name)"
}

let weakIDSClasses: [String] = [
    "IDSInternalQueueController",
    "_IDSAccount",
    "_IDSService",
    "_IDSConnection",
    "_IDSService",
    "_IDSSession"
]

let package = Package(
    name: "DistributedXPC",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "DistributedXPC",
            targets: ["DistributedXPC"]),
        .executable(name: "test", targets: ["test"]),
        .executable(name: "xpcidsd", targets: ["xpcidsd"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/EricRabil/XPCCollections", from: "0.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "DistributedXPC",
            dependencies: ["XPCCollections"]),
        .executableTarget(name: "test", dependencies: ["DistributedXPC"]),
        .testTarget(
            name: "DistributedXPCTests",
            dependencies: ["DistributedXPC"]),
        .executableTarget(name: "xpcidsd", dependencies: ["DistributedXPC", "IDS"]),
        .target(name: "CIDS", linkerSettings: [
            .unsafeFlags(["-F/System/Library/PrivateFrameworks", "-framework", "IDS", "-framework", "IDSFoundation"]),
            .unsafeFlags(weakIDSClasses.map(weakClass(_:)))
        ]),
        .target(name: "IDS", dependencies: ["CIDS"])
    ]
)
