//
//  SettingsStore.swift
//  oumleh
//

import Foundation

/// What the app remembers between launches: the user's currency list, and the
/// last rates it managed to fetch.
///
/// `UserDefaults` rather than a file or SwiftData — a handful of kilobytes of
/// preference-shaped data is exactly what it's for. Both values go in as JSON,
/// so `Currency` and `RatesSnapshot` are saved as they already are instead of
/// needing a parallel set of plist-friendly types.
struct SettingsStore {

    /// Injectable so previews get a throwaway domain of their own rather than
    /// scribbling over the real app's saved list.
    var defaults: UserDefaults = .standard

    private enum Key {
        static let currencies = "currencies"
        static let lastRates = "lastRates"
    }

    // MARK: - The user's list

    /// The saved list, or nil on a first run.
    ///
    /// Nil rather than an empty array because the two mean different things:
    /// "never saved anything" starts from the starter list, while "saved an
    /// empty list" is a user who deleted every row and should get it back.
    func loadCurrencies() -> [Currency]? {
        decode([Currency].self, forKey: Key.currencies)
    }

    func save(currencies: [Currency]) {
        encode(currencies, forKey: Key.currencies)
    }

    // MARK: - The last rates we saw

    /// The last rates fetched successfully, so the app opens on real figures
    /// with their real timestamp instead of a screen of dashes.
    func loadSnapshot() -> RatesSnapshot? {
        decode(RatesSnapshot.self, forKey: Key.lastRates)
    }

    func save(snapshot: RatesSnapshot) {
        encode(snapshot, forKey: Key.lastRates)
    }

    // MARK: - JSON in and out

    /// A value that won't decode is one an older build wrote in a shape this
    /// one no longer understands. Dropping it costs a single refresh, so it's
    /// treated as "nothing saved" rather than reported.
    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: - Previews

extension SettingsStore {
    /// A store nothing else can see, optionally pre-filled.
    ///
    /// Previews need a known starting point, and they'd otherwise share — and
    /// overwrite — whatever the real app has saved.
    static func ephemeral(currencies: [Currency]? = nil,
                          snapshot: RatesSnapshot? = nil) -> SettingsStore {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)")!)
        if let currencies { store.save(currencies: currencies) }
        if let snapshot { store.save(snapshot: snapshot) }
        return store
    }
}
