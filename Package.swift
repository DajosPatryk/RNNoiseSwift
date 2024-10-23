import PackageDescription

let package = Package(
    name: "RNNoiseSwift",
    platforms: [
        .iOS(.v15)
    ],
    products: [
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
        .target(
            name: "RNNoiseSwift",
            path: "Sources/RNNoiseSwift"
        ),
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
                "src/x86",
                "src/dump_features.c",
                "src/dump_rnnoise_tables.c",
                "src/write_weights.c",
                "src/rnnoise_data_little.c"		// Include when using small model
            ],
			publicHeadersPath: "include",
			cSettings: [
				.headerSearchPath("."),
                .headerSearchPath("./src"),
                //.headerSearchPath("./x86"), Do not use for arm64

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
