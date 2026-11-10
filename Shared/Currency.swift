//
//  Currency.swift
//  FX
//

import Foundation

/// One currency in the user's list.
///
/// `nonisolated` because it's plain data: the widget reads it off the main
/// actor, and the app target would otherwise pin it there by default.
nonisolated struct Currency: Identifiable, Hashable, Codable, Sendable {
    /// ISO 4217 code, e.g. "USD".
    let code: String
    /// Human readable name, e.g. "US Dollar".
    let name: String

    var id: String { code }
}

// MARK: - Flag

nonisolated extension Currency {
    /// The ISO country code the flag is drawn from, or nil for a currency with
    /// no one country behind it.
    ///
    /// For almost every ISO 4217 code the first two letters are the country:
    /// "USD" -> "US", "EUR" -> "EU". The exceptions are handled here rather
    /// than left to chance, because the first two letters of "BTC" are also
    /// Bhutan's, and gold, silver and the CFA franc all start "XA".
    var countryCode: String? {
        if let override = Self.flagOverrides[code] { return override }
        // ISO reserves every "X.." code for things that aren't one country's:
        // metals (XAU), the IMF's XDR, the shared regional francs (XOF, XAF).
        guard code.count == 3, !code.hasPrefix("X"), !Self.cryptoCodes.contains(code) else {
            return nil
        }
        return String(code.prefix(2))
    }

    /// Codes whose first two letters name a country that no longer exists.
    private static let flagOverrides: [String: String] = [
        "ANG": "CW",   // Netherlands Antillean guilder: Curaçao still uses it
    ]

    /// Three-letter crypto tickers a feed may carry. Their first two letters
    /// would otherwise borrow a real country's flag.
    private static let cryptoCodes: Set<String> = [
        "BTC", "ETH", "ADA", "LTC", "BCH", "BNB", "DOT", "SOL", "UNI", "LNK",
    ]
}

// MARK: - Starter list

nonisolated extension Currency {
    /// The list the app starts with. The first entry is the main currency, so
    /// USD is the default main with EUR and GBP below it. Names come from the
    /// catalogue so they match everything shown in the "add currency" sheet.
    static let starterList: [Currency] = ["USD", "EUR", "GBP"]
        .compactMap(CurrencyCatalog.currency(for:))
}
