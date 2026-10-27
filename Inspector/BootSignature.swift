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
        check(executable: resolveExecutable(from: raw)).status
    }

    /// Signature state plus the signer's name for an executable path. Paths can
    /// contain spaces ("Application Support"), so callers pass the plist's
    /// `Program` or `ProgramArguments[0]` as is rather than a joined string.
    static func check(executable path: String?) -> (status: BootSignatureStatus, signer: String?) {
        guard let path else { return (.missing, nil) }
        guard path.hasPrefix("/") else { return (.unknown, nil) }
        guard FileManager.default.fileExists(atPath: path) else { return (.missing, nil) }

        var staticCode: SecStaticCode?
        let create = SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &staticCode)
        guard create == errSecSuccess, let staticCode else { return (.unknown, nil) }

        guard SecStaticCodeCheckValidity(staticCode, [], nil) == errSecSuccess else { return (.unsigned, nil) }
        return (.valid, signer(of: staticCode))
    }

    /// "Developer ID Application: Google LLC (EQHXZ8M8AV)" → "Google LLC".
    /// Apple's own binaries carry "Software Signing". Ad hoc signatures have no
    /// certificate, so they return nil.
    private static func signer(of code: SecStaticCode) -> String? {
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any],
              let certificates = dict[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first,
              let summary = SecCertificateCopySubjectSummary(leaf) as String?
        else { return nil }

        if summary == "Software Signing" || summary.hasPrefix("Apple Mac OS") { return "Apple" }
        var name = summary
        if let colon = name.range(of: ": ") { name = String(name[colon.upperBound...]) }
        if let team = name.range(of: " (", options: .backwards), name.hasSuffix(")") {
            name = String(name[..<team.lowerBound])
        }
        return name.isEmpty ? nil : name
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
