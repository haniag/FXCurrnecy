//
//  RatesProvider.swift
//  oumleh
//

import Foundation

/// A set of rates and the moment the service struck them.
///
/// The time travels with the rates rather than being noted when the reply
/// lands: a feed can hand back figures quoted hours earlier, and "updated just
/// now" over yesterday's numbers would be a lie.
struct RatesSnapshot: Sendable, Codable {
    /// Units of each currency per 1 USD.
    let rates: [String: Decimal]
    /// When the service quoted them — not when we asked.
    let quotedAt: Date
}

/// Where live rates come from.
///
/// A protocol rather than a concrete type so the rest of the app doesn't care
/// which service ends up behind it: swapping providers is a one-line change in
/// `ContentView`, and the previews can hand over fixed numbers.
protocol RatesProvider: Sendable {
    /// Rates for the currencies asked for, as units per 1 USD.
    ///
    /// The live service sends every currency it carries in one response, so
    /// `codes` is what the provider keeps, not what it requests.
    func rates(for codes: [String]) async throws -> RatesSnapshot
}

/// Stand-in used by previews and tests.
///
/// Hands back the hand-entered figures from `Currency.sampleRates`, filtered to
/// what was asked for. A currency that list doesn't carry is simply absent, so
/// its row shows "—" rather than a wrong number.
struct SampleRatesProvider: RatesProvider {
    func rates(for codes: [String]) async throws -> RatesSnapshot {
        RatesSnapshot(
            rates: Currency.sampleRates.filter { codes.contains($0.key) },
            quotedAt: .now
        )
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
