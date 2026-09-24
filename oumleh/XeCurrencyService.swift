//
//  XeCurrencyService.swift
//  oumleh
//

import Foundation

/// Fetches the list of currencies Xe supports.
///
/// An `actor` rather than a plain type: the list is kept after the first fetch,
/// and an actor is Swift's way of making shared state like that safe to touch
/// from anywhere without locking of our own.
actor XeCurrencyService {

    static let shared = XeCurrencyService()

    private var cached: [Currency]?

    private static let endpoint = URL(
        string: "https://launchpad-api.xe.com/resources/currencies?country=US&countryTo=US"
    )!

    /// Every currency Xe supports, ordered by code.
    ///
    /// The first call fetches; later ones reuse the result. Xe sends
    /// `Cache-Control: no-store`, so URLSession won't keep a copy for us, and
    /// the list of world currencies doesn't change while the app is open.
    func currencies() async throws -> [Currency] {
        if let cached { return cached }

        let (data, response) = try await URLSession.shared.data(from: Self.endpoint)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw XeError.badStatus(http.statusCode)
        }

        let currencies = try JSONDecoder()
            .decode([XeCurrency].self, from: data)
            .map { Currency(code: $0.isoCode, name: $0.name) }
            .sorted { $0.code < $1.code }   // Xe already sorts them; this keeps it true if that changes

        cached = currencies
        return currencies
    }
}

// MARK: - Wire format

/// One entry of Xe's `/resources/currencies` response.
///
/// Its own type rather than decoding straight into `Currency`: the field names
/// and the extra fields are Xe's to change, and a separate type keeps that away
/// from the model the rest of the app uses. Xe sends more per currency
/// (`amountPrecision`, trading flags); anything not listed here is ignored.
private struct XeCurrency: Decodable {
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
