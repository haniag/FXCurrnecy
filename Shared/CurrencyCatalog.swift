//
//  CurrencyCatalog.swift
//  FX
//

import Foundation

/// Every currency the system knows about.
///
/// Codes and names come from Foundation rather than a list we maintain, so the
/// names arrive already translated into the user's language. It needs no
/// network, which makes it the add sheet's last resort when Xe's list can't be
/// fetched and none was saved.
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
}
