//
//  Currency.swift
//  oumleh
//

import Foundation

/// One currency in the user's list.
struct Currency: Identifiable, Hashable, Codable {
    /// ISO 4217 code, e.g. "USD".
    let code: String
    /// Human readable name, e.g. "US Dollar".
    let name: String

    var id: String { code }
}

// MARK: - Flag

extension Currency {
    /// The ISO country code the flag is drawn from.
    ///
    /// For almost every ISO 4217 code the first two letters are the country:
    /// "USD" -> "US", "EUR" -> "EU". Codes that aren't country based, like the
    /// metals ("XAU"), fall through to a neutral badge in `FlagIcon`.
    var countryCode: String { String(code.prefix(2)) }
}

// MARK: - Placeholder data
//
// Both of these go away once the Xe API is in.

extension Currency {
    /// The list the app starts with. The first entry is the main currency, so
    /// USD is the default main with EUR and GBP below it. Names come from the
    /// catalogue so they match everything shown in the "add currency" sheet.
    static let starterList: [Currency] = ["USD", "EUR", "GBP"]
        .compactMap(CurrencyCatalog.currency(for:))

    /// Units of each currency per 1 USD.
    ///
    /// NOT REAL RATES. The first six came from the design mock-up; the rest are
    /// rough figures so the add-currency flow is usable before the Xe API is
    /// wired up. Anything missing here shows "—" rather than a wrong number.
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
