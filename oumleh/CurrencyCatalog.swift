//
//  CurrencyCatalog.swift
//  oumleh
//

import Foundation

/// Every currency the system knows about.
///
/// Codes and names come from Foundation rather than a list we maintain, so the
/// names arrive already translated into the user's language.
///
/// `nonisolated` because this is immutable lookup data with no tie to the UI.
/// The project defaults every type to the main actor, which would otherwise make
/// `Currency.starterList` — built before any screen exists — an isolation error.
nonisolated enum CurrencyCatalog {

    /// All ISO 4217 currencies in common use, ordered by code.
    static let all: [Currency] = Locale.commonISOCurrencyCodes
        .compactMap { code in
            guard let name = Locale.current.localizedString(forCurrencyCode: code) else { return nil }
            return Currency(code: code, name: name)
        }
        .sorted { $0.code < $1.code }

    static func currency(for code: String) -> Currency? {
        all.first { $0.code == code }
    }

    /// The currency's glyph, e.g. "$" or "€".
    ///
    /// Many currencies have no glyph of their own and Foundation hands back the
    /// code instead ("JOD"). Those return nil, so callers don't print the code
    /// twice.
    static func symbol(for code: String) -> String? { symbolsByCode[code] }

    /// Built once: a NumberFormatter per row would be wasteful in a long list.
    private static let symbolsByCode: [String: String] = {
        var result: [String: String] = [:]
        for currency in all {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency.code
            if let symbol = formatter.currencySymbol, symbol != currency.code {
                result[currency.code] = symbol
            }
        }
        return result
    }()
}
