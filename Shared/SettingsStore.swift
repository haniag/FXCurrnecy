//
//  SettingsStore.swift
//  FX
//

import Foundation

/// What the app remembers between launches: the user's currency list, the
/// last rates it managed to fetch, and the list of currencies on offer.
///
/// `UserDefaults` rather than a file or SwiftData — a handful of kilobytes of
/// preference-shaped data is exactly what it's for. Every value goes in as
/// JSON, so `Currency` and `RatesSnapshot` are saved as they already are
/// instead of needing a parallel set of plist-friendly types.
///
/// The defaults live in the app group, not the app's own domain, because the
/// home-screen widget is a separate process and reads the same list and rates.
nonisolated struct SettingsStore: @unchecked Sendable {

    /// The group the app and its widget share. Has to match the
    /// `com.apple.security.application-groups` entry in both entitlements files.
    static let appGroup = "group.com.fursa.fx"

    /// Injectable so previews and tests get a throwaway domain of their own
    /// rather than scribbling over the real app's saved list.
    var defaults: UserDefaults = SettingsStore.sharedDefaults

    private enum Key {
        static let currencies = "currencies"
        static let lastRates = "lastRates"
        static let catalog = "currencyCatalog"

        /// What builds from before the widget kept in the app's own domain.
        static let migrated = [currencies, lastRates]
    }

    /// The app group's defaults, with anything an older build saved in the
    /// app's own domain carried across the first time.
    ///
    /// A static, so the copy happens once per launch however many stores are
    /// made. In the widget `.standard` is the widget's own empty domain, and
    /// the loop finds nothing to copy.
    private static let sharedDefaults: UserDefaults = {
        guard let shared = UserDefaults(suiteName: appGroup) else { return .standard }
        for key in Key.migrated where shared.data(forKey: key) == nil {
            if let old = UserDefaults.standard.data(forKey: key) {
                shared.set(old, forKey: key)
            }
        }
        return shared
    }()

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

    // MARK: - The currencies on offer

    /// The list behind the add sheet as last fetched, so the sheet opens
    /// straight away and works with no connection.
    func loadCatalog() -> [Currency]? {
        decode([Currency].self, forKey: Key.catalog)
    }

    func save(catalog: [Currency]) {
        encode(catalog, forKey: Key.catalog)
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

// MARK: - Previews and tests

nonisolated extension SettingsStore {
    /// A store nothing else can see, optionally pre-filled.
    ///
    /// Previews and tests need a known starting point, and they'd otherwise
    /// share — and overwrite — whatever the real app has saved.
    static func ephemeral(currencies: [Currency]? = nil,
                          snapshot: RatesSnapshot? = nil) -> SettingsStore {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "preview.\(UUID().uuidString)")!)
        if let currencies { store.save(currencies: currencies) }
        if let snapshot { store.save(snapshot: snapshot) }
        return store
    }
}
