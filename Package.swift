// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RNNoiseSwift",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        //.library(
		//	name: "RNNoise",
		//	targets: ["RNNoise"]
		//),
        .library(
            name: "CRNNoise",
            targets: ["CRNNoise"]
        ),
        .library(
            name: "RNNoiseSwift",
            targets: ["RNNoiseSwift", "CRNNoise"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RNNoiseSwift",
            path: "Sources/RNNoiseSwift"
        ),
        //.binaryTarget(
        //    name: "RNNoise",
        //    path: "RNNoise.xcframework"
        //),
        .target(
			name: "CRNNoise",
            path: "Libraries/RNNoise",
			exclude: [
				"AUTHORS",
				"autogen.sh",
				"configure.ac",
				"COPYING",
				"doc",
				"examples",
				"m4",
				"Makefile.am",
				"TRAINING-README",
				"datasets.txt",
				"rnnoise-uninstalled.pc.in",
				"rnnoise.pc.in",
				"README",
                "scripts",
				"training",
				"update_version",
                "torch",
                "src/x86"
			],
			publicHeadersPath: "include",
			cSettings: [
				.headerSearchPath("."),
                .headerSearchPath("./src"),
                //.headerSearchPath("./x86"),

				.define("RNNOISE_BUILD"),

				.define("HAVE_DLFCN_H", to: "1"),
				.define("HAVE_INTTYPES_H", to: "1"),
				.define("HAVE_LRINT", to: "1"),
				.define("HAVE_LRINTF", to: "1"),
				.define("HAVE_MEMORY_H", to: "1"),
				.define("HAVE_STDINT_H", to: "1"),
				.define("HAVE_STDLIB_H", to: "1"),
				.define("HAVE_STRING_H", to: "1"),
				.define("HAVE_STRINGS_H", to: "1"),
				.define("HAVE_SYS_STAT_H", to: "1"),
				.define("HAVE_SYS_TYPES_H", to: "1"),
				.define("HAVE_UNISTD_H", to: "1"),
			]
		)
    ]
)
