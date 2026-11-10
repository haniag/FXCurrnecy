//
//  CurrencyTests.swift
//  FXTests
//

import Foundation
import Testing
@testable import FX

/// Which flag a currency gets, and where the add sheet's list comes from.
struct CurrencyTests {

    // MARK: - Flags

    @Test func mostCodesStartWithTheirCountry() {
        #expect(Currency(code: "USD", name: "").countryCode == "US")
        #expect(Currency(code: "EUR", name: "").countryCode == "EU")
        #expect(Currency(code: "JOD", name: "").countryCode == "JO")
    }

    @Test func metalsAndSharedCurrenciesHaveNoCountry() {
        for code in ["XAU", "XAG", "XDR", "XOF", "XAF", "XCD"] {
            #expect(Currency(code: code, name: "").countryCode == nil, "\(code)")
        }
    }

    /// "BT" is Bhutan and "ET" is Ethiopia; neither issued these.
    @Test func cryptoDoesNotBorrowACountrysFlag() {
        #expect(Currency(code: "BTC", name: "").countryCode == nil)
        #expect(Currency(code: "ETH", name: "").countryCode == nil)
        #expect(Currency(code: "DOGE", name: "").countryCode == nil)
    }

    @Test func aVanishedCountryUsesItsSuccessor() {
        #expect(Currency(code: "ANG", name: "").countryCode == "CW")
    }

    // MARK: - The add sheet's list

    private let fetched = [Currency(code: "AED", name: "Emirati Dirham")]
    private let saved = [Currency(code: "JOD", name: "Jordanian Dinar")]

    @Test func aFetchedListIsSavedForNextTime() async throws {
        let store = SettingsStore.ephemeral()
        let service = XeCurrencyService(store: store) { [fetched] in fetched }
        #expect(try await service.currencies() == fetched)
        #expect(store.loadCatalog() == fetched)
    }

    @Test func aSavedListNeedsNoNetwork() async throws {
        let store = SettingsStore.ephemeral()
        store.save(catalog: saved)
        let service = XeCurrencyService(store: store) { throw URLError(.notConnectedToInternet) }
        #expect(try await service.currencies() == saved)
    }

    @Test func withNothingSavedAndNoNetworkTheSystemListStandsIn() async throws {
        let service = XeCurrencyService(store: .ephemeral()) { throw URLError(.notConnectedToInternet) }
        let list = try await service.currencies()
        #expect(list == CurrencyCatalog.all)
        #expect(list.contains { $0.code == "USD" })
    }
}
