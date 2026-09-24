//
//  LiveRatesProvider.swift
//  oumleh
//

import Foundation

/// Live rates from the new rates service.
///
/// One GET returns every currency the service carries — hundreds of them,
/// including crypto and metals — each quoted as units per 1 USD, which is
/// already the shape the app works in. All of them are kept, not only the
/// ones on screen, so the add sheet can show a rate for every currency.
struct LiveRatesProvider: RatesProvider {

    // MARK: - Details to fill in
    //
    // Both are nil until the provider sends them over. While either is
    // missing, the app doesn't attempt a call at all; the footer says the
    // service isn't set up yet, rather than showing a 401.

    /// The GET endpoint that returns the rates.
    ///
    ///     var endpoint: URL? = URL(string: "https://rates.example.com/v1/latest")
         
     var endpoint: URL? = nil

    /// The key, sent as the `Authorization` header with its scheme included
    /// ("Basic …" or "Bearer …"). It lives in `Secrets.swift`, which git
    /// ignores, so the key itself never lands in the repository.
    var authorization: String? = Secrets.ratesAuthorization

    // MARK: - Wiring

    var session: URLSession = .shared

    func rates(for codes: [String]) async throws -> RatesSnapshot {
        guard let endpoint, let authorization else { throw RatesError.notConfigured }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // `Authorization` is one of the headers Apple's URL Loading System
        // treats as reserved: on a redirect it builds the follow-up request
        // itself and drops the header rather than carrying it over. Xe's
        // endpoint can redirect, so without this delegate the second request
        // goes out unauthenticated even though we set the header above.
        let redirectDelegate = AuthorizationPreservingRedirectDelegate(authorization: authorization)
        let (data, response) = try await session.data(for: request, delegate: redirectDelegate)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RatesError.badStatus(http.statusCode)
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)

        // The feed sends the whole world, and all of it is kept: the add sheet
        // shows a rate beside every currency, and a newly added one has its
        // rate straight away. A code the feed doesn't carry is simply absent,
        // and its row shows "—" rather than a wrong number.
        return RatesSnapshot(
            rates: payload.rates,
            quotedAt: Date(timeIntervalSince1970: Double(payload.timestamp) / 1000)
        )
    }
}

/// Re-adds the `Authorization` header on redirect.
///
/// `URLSession` builds the redirected request itself and strips reserved
/// headers like `Authorization` in the process; without this, a redirecting
/// endpoint silently loses the header on the follow-up request.
private final class AuthorizationPreservingRedirectDelegate: NSObject, URLSessionTaskDelegate {
    private let authorization: String

    init(authorization: String) {
        self.authorization = authorization
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var redirected = request
        redirected.setValue(authorization, forHTTPHeaderField: "Authorization")
        completionHandler(redirected)
    }
}

// MARK: - Wire format

/// The service's response: one timestamp and every rate it carries.
private struct Payload: Decodable {
    /// When the rates were quoted, in milliseconds since 1970 — note the
    /// milliseconds, which is why it's divided through above rather than
    /// handed straight to `Date(timeIntervalSince1970:)`.
    let timestamp: Int

    /// Units of each currency per 1 USD, keyed by code.
    let rates: [String: Decimal]
}
