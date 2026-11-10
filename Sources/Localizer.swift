import Foundation

protocol Localizing {
    func t(_ key: String, _ args: CVarArg...) -> String
}

/// Looks up keys in the user's language, falls back to EN (source) when a key is missing or empty.
final class BundleLocalizer: Localizing {
    private static let missing = "\u{0}missing"
    private let bundle: Bundle
    private let fallback: Bundle?

    init(bundle: Bundle = .main, fallbackLanguage: String = "en") {
        self.bundle = bundle
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
