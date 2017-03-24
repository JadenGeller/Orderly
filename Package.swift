
import PackageDescription

let package = Package(
    name: "Orderly",
    dependencies: [
        .Package(url: "https://github.com/JadenGeller/Comparator.git", majorVersion: 2)
    ]
)
