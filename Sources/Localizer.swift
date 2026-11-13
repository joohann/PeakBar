import Foundation

protocol Localizing {
    func t(_ key: String, _ args: CVarArg...) -> String
}

/// Looks up keys in the user's language, falls back to EN (source) when a key is missing or empty.
final class BundleLocalizer: Localizing {
    private static let missing = "\u{0}missing"
    private let bundle: Bundle
    private let fallback: Bundle?

    /// `language` forces one language (used by the previews); nil follows the user's macOS language.
    init(bundle: Bundle = .main, language: String? = nil, fallbackLanguage: String = "en") {
        self.bundle = language.flatMap { bundle.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? bundle
        self.fallback = bundle.path(forResource: fallbackLanguage, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    func t(_ key: String, _ args: CVarArg...) -> String {
        let format = lookup(key)
        return args.isEmpty ? format : String(format: format, locale: .current, arguments: args)
    }

    private func lookup(_ key: String) -> String {
        let value = bundle.localizedString(forKey: key, value: Self.missing, table: nil)
        if value != Self.missing && !value.isEmpty { return value }
        let base = fallback?.localizedString(forKey: key, value: Self.missing, table: nil)
        if let base, base != Self.missing, !base.isEmpty { return base }
        return key
    }
}
