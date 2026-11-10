//
//  XeCurrencyService.swift
//  FX
//

import Foundation

/// The list of currencies behind the add sheet.
///
/// Xe's list is the one to show, since it's the currencies Xe can quote. But
/// it rarely changes, so it's saved after each fetch and the saved copy is
/// handed back first: the sheet opens at once, and works with no connection.
/// A fresh copy is fetched behind it once per launch, for next time.
///
/// An `actor` rather than a plain type: the list is kept after the first call,
/// and an actor is Swift's way of making shared state like that safe to touch
/// from anywhere without locking of our own.
actor XeCurrencyService {

    static let shared = XeCurrencyService()

    private var cached: [Currency]?
    /// True once this launch has fetched, or started fetching, a fresh list.
    private var hasRefreshed = false

    private let store: SettingsStore
    private let fetch: @Sendable () async throws -> [Currency]

    /// `fetch` is swappable so the tests can stand in for the network.
    init(store: SettingsStore = SettingsStore(),
         fetch: @escaping @Sendable () async throws -> [Currency] = XeCurrencyService.fetchFromXe) {
        self.store = store
        self.fetch = fetch
    }

    /// Every currency on offer, ordered by code.
    ///
    /// In order of preference: the list already in memory; the one saved by an
    /// earlier launch, refreshed in the background; a fresh fetch; and, with
    /// no connection and nothing saved, the system's own list of currencies.
    /// That last one may name a currency Xe has no rate for, whose row then
    /// shows "—", which beats a sheet that can't add anything at all.
    func currencies() async throws -> [Currency] {
        if let cached { return cached }

        if let saved = store.loadCatalog(), !saved.isEmpty {
            cached = saved
            refreshInBackground()
            return saved
        }

        do {
            return try await refresh()
        } catch {
            let fallback = CurrencyCatalog.all
            // Not cached: the next time the sheet opens, Xe gets another try.
            guard !fallback.isEmpty else { throw error }
            return fallback
        }
    }

    /// Fetch, keep and save a fresh list.
    @discardableResult
    private func refresh() async throws -> [Currency] {
        hasRefreshed = true
        do {
            let fresh = try await fetch()
            cached = fresh
            store.save(catalog: fresh)
            return fresh
        } catch {
            hasRefreshed = false   // let a later call try again
            throw error
        }
    }

    /// Once per launch. A failure is ignored: the saved list is already on
    /// screen, and the next launch tries again.
    private func refreshInBackground() {
        guard !hasRefreshed else { return }
        hasRefreshed = true
        Task { try? await refresh() }
    }

    // MARK: - Xe

    private static let endpoint = URL(
        string: "https://launchpad-api.xe.com/resources/currencies?country=US&countryTo=US"
    )!

    /// Xe sends `Cache-Control: no-store`, so URLSession won't keep a copy for
    /// us; the saving above is what stands in for it.
    private static let fetchFromXe: @Sendable () async throws -> [Currency] = {
        let (data, response) = try await URLSession.shared.data(from: endpoint)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw XeError.badStatus(http.statusCode)
        }

        return try JSONDecoder()
            .decode([XeCurrency].self, from: data)
            .map { Currency(code: $0.isoCode, name: $0.name) }
            .sorted { $0.code < $1.code }   // Xe already sorts them; this keeps it true if that changes
    }
}

// MARK: - Wire format

/// One entry of Xe's `/resources/currencies` response.
///
/// Its own type rather than decoding straight into `Currency`: the field names
/// and the extra fields are Xe's to change, and a separate type keeps that away
/// from the model the rest of the app uses. Xe sends more per currency
/// (`amountPrecision`, trading flags); anything not listed here is ignored.
private nonisolated struct XeCurrency: Decodable {
    let isoCode: String
    let name: String
}

// MARK: - Errors

enum XeError: LocalizedError {
    /// Xe answered, but not with a success code.
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            "Xe replied with status \(code)."
        }
    }
}
