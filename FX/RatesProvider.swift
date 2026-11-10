//
//  RatesProvider.swift
//  FX
//

import Foundation

/// Where live rates come from.
///
/// A protocol rather than a concrete type so the rest of the app doesn't care
/// which service ends up behind it: swapping providers is a one-line change in
/// `ContentView`, and the previews can hand over fixed numbers.
protocol RatesProvider: Sendable {
    /// Rates for at least the currencies asked for, as units per 1 USD.
    ///
    /// The live service sends every currency it carries in one response, and
    /// the provider hands all of it back, so the add sheet can show rates for
    /// currencies that aren't on the list yet.
    func rates(for codes: [String]) async throws -> RatesSnapshot
}

// MARK: - Errors

/// Something went wrong fetching live rates.
enum RatesError: LocalizedError, Sendable {
    /// The server answered, but not with a success code.
    case badStatus(Int)
    /// The service's address or key hasn't been filled in yet.
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): "The rates service replied with status \(code)."
        case .notConfigured: "The rates service isn't set up yet."
        }
    }
}

// MARK: - Stand-ins
//
// Previews and tests only: compiled into debug builds and nothing else.

#if DEBUG

/// Stand-in used by previews and tests.
///
/// Hands back all the hand-entered figures from `Currency.sampleRates`, the
/// way the live service hands back everything it carries. A currency that list
/// doesn't carry is simply absent, so its row shows "—" rather than a wrong
/// number.
struct SampleRatesProvider: RatesProvider {
    func rates(for codes: [String]) async throws -> RatesSnapshot {
        RatesSnapshot(rates: Currency.sampleRates, quotedAt: .now)
    }
}

/// Never finishes, so previews can sit in the loading state.
struct StalledRatesProvider: RatesProvider {
    func rates(for codes: [String]) async throws -> RatesSnapshot {
        try await Task.sleep(for: .seconds(60 * 60))
        return RatesSnapshot(rates: [:], quotedAt: .now)
    }
}

/// Always fails, so previews can show what a failure looks like. The error is
/// settable because the two that matter read very differently on screen: a
/// service that was never set up, and one that turned us away.
struct FailingRatesProvider: RatesProvider {
    var error: RatesError = .notConfigured

    func rates(for codes: [String]) async throws -> RatesSnapshot {
        throw error
    }
}

// MARK: - Sample rates

extension Currency {
    /// Units of each currency per 1 USD.
    ///
    /// NOT REAL RATES. Rough hand-entered figures for the previews and tests;
    /// the whole block is left out of release builds, so none of them can
    /// reach a user's screen. Anything missing here shows "—" rather than a
    /// wrong number.
    static let sampleRates: [String: Decimal] = [
        "USD": 1, "ILS": 3.012, "GBP": 0.748, "EUR": 0.872, "JOD": 0.709, "TRY": 48.811,
        "JPY": 155, "CHF": 0.80, "CAD": 1.38, "AUD": 1.52, "NZD": 1.68,
        "CNY": 7.12, "HKD": 7.78, "SGD": 1.30, "INR": 88.5, "KRW": 1390,
        "SEK": 9.45, "NOK": 10.2, "DKK": 6.50, "PLN": 3.62, "CZK": 21.1,
        "HUF": 335, "RON": 4.35, "ISK": 124, "UAH": 41.5, "RUB": 81,
        "AED": 3.6725, "SAR": 3.75, "QAR": 3.64, "KWD": 0.306, "BHD": 0.376,
        "OMR": 0.3845, "EGP": 47.8, "MAD": 9.05, "LBP": 89500, "IQD": 1310,
        "ZAR": 17.4, "NGN": 1450, "KES": 129, "GHS": 12.4, "TND": 2.95,
        "BRL": 5.35, "MXN": 18.3, "ARS": 1450, "CLP": 940, "COP": 3850, "PEN": 3.45,
        "PKR": 279, "BDT": 121, "LKR": 296, "PHP": 58.2, "THB": 32.3,
        "MYR": 4.18, "IDR": 16400, "VND": 26300, "TWD": 30.6,
    ]
}

#endif
