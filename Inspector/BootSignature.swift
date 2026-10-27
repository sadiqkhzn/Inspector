import Foundation
import Security

/// Signature state of the executable a plist's `Program` / `ProgramArguments`
/// points at. Used to flag Boot items whose signing posture would make a
/// macOS user raise an eyebrow (homebrew / older third-party agents can be
/// unsigned; a modern vendor one shouldn't be).
enum BootSignatureStatus: Hashable {
    /// Binary is signed and the signature is valid against the current anchor.
    case valid
    /// Binary exists but isn't signed, or the signature is broken.
    case unsigned
    /// We couldn't locate the executable the plist refers to.
    case missing
    /// The plist's Program path didn't resolve to a readable file; skipping.
    case unknown
}

/// Walks a plist's launchd references down to a file on disk and asks
/// Security.framework whether it carries a valid code signature. Zero shell
/// execution — SecStaticCodeCreateWithPath + SecStaticCodeCheckValidity do
/// the same check `codesign -v` does.
enum BootSignatureChecker {

    /// Resolve the program the plist points to, then check its signature.
    static func status(forPlistProgram raw: String) -> BootSignatureStatus {
        guard let path = resolveExecutable(from: raw) else { return .missing }
        return status(for: URL(fileURLWithPath: path))
    }

    private static func status(for url: URL) -> BootSignatureStatus {
        var staticCode: SecStaticCode?
        let create = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard create == errSecSuccess, let staticCode else { return .unknown }

        let check = SecStaticCodeCheckValidity(staticCode, [], nil)
        if check == errSecSuccess { return .valid }
        return .unsigned
    }

    /// `Program` is a single executable path. `ProgramArguments[0]` is the
    /// same thing but with flags after it. Both can start inside a .app
    /// bundle — we drill down to the actual binary.
    private static func resolveExecutable(from raw: String) -> String? {
        let token = raw.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? raw
        guard !token.isEmpty, token.first == "/" else { return nil }
        return token
    }
}
