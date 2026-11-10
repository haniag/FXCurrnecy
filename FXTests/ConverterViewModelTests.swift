//
//  ConverterViewModelTests.swift
//  FXTests
//

import Foundation
import Testing
@testable import FX

/// The list and the arithmetic behind the main screen. Each test gets a store
/// of its own, so nothing here touches the real app's saved list.
@MainActor
struct ConverterViewModelTests {

    private let usd = Currency(code: "USD", name: "US Dollar")
    private let eur = Currency(code: "EUR", name: "Euro")
    private let gbp = Currency(code: "GBP", name: "British Pound")
    private let lbp = Currency(code: "LBP", name: "Lebanese Pound")

    private func makeModel(_ currencies: [Currency],
                           provider: RatesProvider? = nil) -> ConverterViewModel {
        ConverterViewModel(
            store: .ephemeral(
                currencies: currencies,
                snapshot: RatesSnapshot(rates: Currency.sampleRates, quotedAt: .now)
            ),
            ratesProvider: provider ?? SampleRatesProvider(),
            reloadWidgets: {}
        )
    }

    // MARK: - Converting

    @Test func convertsFromTheMainCurrency() {
        let model = makeModel([usd, eur, gbp])
        // Compared as printed: the sample rates are written as floating-point
        // literals, which aren't exactly the decimals they look like.
        #expect(model.displayText(for: eur) == NumberText.displayText(Decimal(string: "0.872")!))
        #expect(model.displayText(for: gbp) == NumberText.displayText(Decimal(string: "0.748")!))
    }

    @Test func typedAmountDrivesEveryRow() {
        let model = makeModel([usd, eur])
        model.beginEditing(usd)
        model.updateText("10", for: usd)
        #expect(model.displayText(for: eur) == NumberText.displayText(Decimal(string: "8.72")!))
    }

    @Test func arabicDigitsConvertLikeAnyOthers() {
        let model = makeModel([usd, eur])
        model.beginEditing(usd)
        model.updateText("١٠", for: usd)
        #expect(model.displayText(for: eur) == NumberText.displayText(Decimal(string: "8.72")!))
    }

    @Test func anEmptyFieldCountsAsOne() {
        let model = makeModel([usd, eur])
        model.beginEditing(usd)
        #expect(model.anchorAmount == 1)
        model.commitEditing(for: usd)
        #expect(model.anchorText == "1")
    }

    @Test func aRowWithNoRateHasNoAmount() {
        let unknown = Currency(code: "ZZZ", name: "Nowhere")
        let model = makeModel([usd, unknown])
        #expect(model.convertedAmount(for: unknown) == nil)
        #expect(model.displayText(for: unknown) == "—")
        #expect(model.copyText(for: unknown) == nil)
    }

    @Test func aWeakMainCurrencyStillShowsAnAmount() {
        let model = makeModel([usd, lbp])
        model.makeMain(lbp)
        #expect(model.displayText(for: usd) != "0")
    }

    // MARK: - The list

    @Test func makingARowMainMovesItToTheTopAtOne() {
        let model = makeModel([usd, eur, gbp])
        model.makeMain(gbp)
        #expect(model.currencies.map(\.code) == ["GBP", "USD", "EUR"])
        #expect(model.anchorAmount == 1)
        #expect(model.mainCode == "GBP")
    }

    @Test func addingTwiceAddsOnce() {
        let model = makeModel([usd])
        model.add(eur)
        model.add(eur)
        #expect(model.currencies.map(\.code) == ["USD", "EUR"])
    }

    @Test func aRemovedRowGoesBackWhereItWas() {
        let model = makeModel([usd, eur, gbp])
        model.remove(eur)
        #expect(model.currencies.map(\.code) == ["USD", "GBP"])
        model.restore(eur, at: 1)
        #expect(model.currencies.map(\.code) == ["USD", "EUR", "GBP"])
    }

    @Test func restoringPastTheEndAppends() {
        let model = makeModel([usd, eur])
        model.remove(eur)
        model.restore(eur, at: 9)
        #expect(model.currencies.map(\.code) == ["USD", "EUR"])
    }

    @Test func removingTheMainCurrencyPromotesTheNext() {
        let model = makeModel([usd, eur, gbp])
        model.remove(usd)
        #expect(model.mainCode == "EUR")
        #expect(model.anchorCode == "EUR")
        #expect(model.anchorAmount == 1)
    }

    @Test func theListIsSaved() {
        let store = SettingsStore.ephemeral(currencies: [usd, eur])
        let model = ConverterViewModel(store: store, ratesProvider: SampleRatesProvider(), reloadWidgets: {})
        model.add(gbp)
        #expect(store.loadCurrencies()?.map(\.code) == ["USD", "EUR", "GBP"])
    }

    // MARK: - Refreshing

    @Test func aFailedRefreshKeepsTheOldRates() async {
        let model = makeModel([usd, eur], provider: FailingRatesProvider(error: .badStatus(500)))
        await model.refreshRates()
        #expect(model.hasRates)
        #expect(model.status == .failed(RatesError.badStatus(500).localizedDescription))
    }

    @Test func comingBackSoonDoesNotFetchAgain() async {
        let provider = CountingRatesProvider()
        let model = makeModel([usd, eur], provider: provider)
        await model.refreshRates()
        await model.refreshIfStale(now: .now.addingTimeInterval(60))
        #expect(provider.calls == 1)
    }

    @Test func comingBackLaterFetchesAgain() async {
        let provider = CountingRatesProvider()
        let model = makeModel([usd, eur], provider: provider)
        await model.refreshRates()
        await model.refreshIfStale(now: .now.addingTimeInterval(ConverterViewModel.staleAfter + 1))
        #expect(provider.calls == 2)
    }

    @Test func comingBackAfterAFailureTriesAgain() async {
        let provider = CountingRatesProvider(failing: true)
        let model = makeModel([usd, eur], provider: provider)
        await model.refreshRates()
        await model.refreshIfStale()
        #expect(provider.calls == 2)
    }

    @Test func changesReloadTheWidget() async {
        var reloads = 0
        let model = ConverterViewModel(
            store: .ephemeral(currencies: [usd]),
            ratesProvider: SampleRatesProvider(),
            reloadWidgets: { reloads += 1 }
        )
        model.add(eur)
        await model.refreshRates()
        #expect(reloads == 2)
    }
}

/// Counts how often it's asked. Only ever used from the main actor.
private final class CountingRatesProvider: RatesProvider, @unchecked Sendable {
    private(set) var calls = 0
    private let failing: Bool

    init(failing: Bool = false) {
        self.failing = failing
    }

    func rates(for codes: [String]) async throws -> RatesSnapshot {
        calls += 1
        if failing { throw RatesError.badStatus(503) }
        return RatesSnapshot(rates: Currency.sampleRates, quotedAt: .now)
    }
}
