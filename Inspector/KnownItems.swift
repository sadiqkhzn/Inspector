import Foundation

struct KnownItemSpec {
    let name: String
    let relativePath: String
    let safety: SafetyLevel
    let category: ScanCategory
    let whatItIs: String
    let whatHappensIfRemoved: String
    let minBytesToShow: Int64

    init(
        _ name: String,
        _ relativePath: String,
        _ safety: SafetyLevel,
        _ category: ScanCategory,
        _ whatItIs: String,
        _ whatHappensIfRemoved: String,
        minBytesToShow: Int64 = 50 * 1024 * 1024
    ) {
        self.name = name
        self.relativePath = relativePath
        self.safety = safety
        self.category = category
        self.whatItIs = whatItIs
        self.whatHappensIfRemoved = whatHappensIfRemoved
        self.minBytesToShow = minBytesToShow
    }
}

enum KnownItems {
    static let catalog: [KnownItemSpec] = [
        KnownItemSpec(
            "Google Chrome cache",
            "Library/Caches/Google",
            .safe, .cache,
            "Chrome's browser cache. Pages, images, scripts kept to speed up repeat visits.",
            "Chrome will rebuild it as you browse. Bookmarks, history, and extensions are untouched."
        ),
        KnownItemSpec(
            "pip cache",
            "Library/Caches/pip",
            .safe, .devTool,
            "Downloaded Python packages kept so repeat installs are instant.",
            "Next pip install re-downloads, otherwise nothing changes."
        ),
        KnownItemSpec(
            "Homebrew cache",
            "Library/Caches/Homebrew",
            .safe, .devTool,
            "Downloaded formula archives from brew install.",
            "Nothing. Already installed packages are unaffected."
        ),
        KnownItemSpec(
            "Docker installer leftover",
            "Library/Application Support/com.docker.install",
            .safe, .installerLeftover,
            "Files the Docker installer left behind after setup.",
            "Nothing. Docker itself is not touched."
        ),
    ]
}
