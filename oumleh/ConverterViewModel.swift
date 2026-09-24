//
//  ConverterViewModel.swift
//  oumleh
//

import Foundation
import Observation
import SwiftUI  // for move(fromOffsets:toOffset:) and remove(atOffsets:)

/// Holds the user's currency list and converts between them.
///
/// Exactly one currency is the "anchor" at any time: the one the user last typed
/// into. Every other row is derived from it, so there is only ever one source of
/// truth for the amount on screen.
// Main-actor isolated already: the project builds with
// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, so `refreshRates()` resumes on the
// main actor and its writes to `rates` are safe without an annotation here.
@Observable
final class ConverterViewModel {

    /// The user's currencies, in display order. The first one is the main currency.
    ///
    /// Saved on every change rather than at each call site: adding, removing,
    /// reordering and promoting a main currency all end up assigning here, and
    /// a single hook is one that can't be forgotten.
    private(set) var currencies: [Currency] {
        didSet { store.save(currencies: currencies) }
    }

    /// Units of each currency per 1 USD.
    private(set) var rates: [String: Decimal]

    /// The currency the user last typed into. Every other row is derived from it.
    private(set) var anchorCode: String

    /// The anchor's amount, kept as text so partial input like "1." behaves while typing.
    private(set) var anchorText: String

    /// The exact amount behind `anchorText`, while the text is still a value we
    /// put there rather than one the user typed.
    ///
    /// `anchorText` is rounded for display, so without this, simply tapping a
    /// row and tapping away would re-derive every other row from the rounded
    /// figure and quietly shift all of them.
    private var untouchedAmount: Decimal?

    /// When the service quoted the rates on screen. Not when we fetched them:
    /// a feed can hand back figures struck hours earlier.
    private(set) var quotedAt: Date

    /// What the rates are doing. One value rather than a flag and an optional
    /// message, so "loading" and "failed" can't both be true at once.
    private(set) var status: RatesStatus = .loading

    /// True once there's something real to convert with. Distinguishes a first
    /// run, where every row shows "—", from a refresh over figures already on
    /// screen.
    var hasRates: Bool { !rates.isEmpty }

    /// Where the rates are in their journey. Starts at `.loading` because the
    /// screen asks for a refresh the moment it appears.
    enum RatesStatus: Equatable {
        case loading
        case loaded
        /// The last fetch failed. Any rates on screen are the previous ones.
        case failed(String)
    }

    private let ratesProvider: RatesProvider
    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore(),
         ratesProvider: RatesProvider = SampleRatesProvider()) {
        self.store = store
        self.ratesProvider = ratesProvider

        // The user's own list, or the starter six the very first time. Held in
        // a local as well, because the anchor below is read before every
        // stored property is in place and `self` isn't usable until then.
        let list = store.loadCurrencies() ?? Currency.starterList
        self.currencies = list

        // The last rates we managed to fetch, so the app opens on real figures
        // with the time they were actually struck. Empty on a first run, which
        // shows "—" in every row — honest about not knowing yet, rather than
        // filling the screen with numbers we made up.
        let saved = store.loadSnapshot()
        self.rates = saved?.rates ?? [:]
        self.quotedAt = saved?.quotedAt ?? .distantPast

        self.anchorCode = list.first?.code ?? "USD"
        self.anchorText = "1"
    }

    // MARK: - Refreshing

    /// Fetch fresh rates: at least the currencies on screen, and in practice
    /// every one the service carries.
    ///
    /// Called when the app starts, on pull-to-refresh, and when the add sheet
    /// closes with a currency that has no rate yet. The codes are read at call
    /// time, which keeps the request in step with the user's list.
    func refreshRates() async {
        let codes = currencies.map(\.code)
        let previousStatus = status
        status = .loading

        do {
            // Replaced wholesale, not merged: a code the provider didn't return
            // has no rate, and showing "—" is better than a stale one.
            let snapshot = try await ratesProvider.rates(for: codes)
            rates = snapshot.rates
            quotedAt = snapshot.quotedAt
            status = .loaded
            // Kept for next launch, so the app opens on these rather than "—".
            store.save(snapshot: snapshot)
        } catch {
            // A cancelled refresh isn't a failure worth reporting: the screen
            // went away, or the user let go of the pull part-way.
            guard !Task.isCancelled else { status = previousStatus; return }
            // The rates already on screen stay put; only the status changes.
            status = .failed(error.localizedDescription)
        }
    }

    /// The main currency: the one at the top of the list that everything is quoted against.
    var mainCode: String { currencies.first?.code ?? anchorCode }

    func currency(for code: String) -> Currency? {
        currencies.first { $0.code == code }
    }

    /// Every currency below the main one: the rows of the list.
    var otherCurrencies: [Currency] { Array(currencies.dropFirst()) }

    // MARK: - Rates

    /// What one of `currency` is worth in the main currency: "1 ILS = 0.332 USD".
    ///
    /// Nil for the main currency itself, and while either rate is missing.
    func inverseRateText(for currency: Currency) -> String? {
        guard currency.code != mainCode,
              let rate = rates[currency.code], rate != 0,
              let main = rates[mainCode]
        else { return nil }
        return "1 \(currency.code) = \(Self.rateText(main / rate)) \(mainCode)"
    }

    /// One of the main currency in `currency`, e.g. "3.673", for the rate
    /// column in the add sheet. Nil while either rate is missing.
    func unitRateText(for currency: Currency) -> String? {
        guard let rate = rates[currency.code],
              let main = rates[mainCode], main != 0
        else { return nil }
        return Self.rateText(rate / main)
    }

    // MARK: - Amounts

    /// Offered when the amount field is selected, and where a new main currency
    /// starts. Quoting against 1 is the common case.
    static let suggestedAmount: Decimal = 1

    /// The amount currently entered in the anchor row. An empty field is the
    /// suggestion still standing, so it counts as 1.
    var anchorAmount: Decimal {
        if let untouchedAmount { return untouchedAmount }
        if anchorText.isEmpty { return Self.suggestedAmount }
        return Self.parse(anchorText) ?? 0
    }

    /// What a row should show: the raw text for the row being typed into, and a
    /// formatted conversion for every other row.
    func displayText(for currency: Currency) -> String {
        if currency.code == anchorCode { return anchorText }
        guard let amount = convertedAmount(for: currency) else { return "—" }
        return Self.displayText(amount)
    }

    /// The anchor amount expressed in `currency`.
    func convertedAmount(for currency: Currency) -> Decimal? {
        guard let target = rates[currency.code],
              let anchor = rates[anchorCode],
              anchor != 0
        else { return nil }
        return anchorAmount * target / anchor
    }

    // MARK: - Editing

    /// A row gained focus. The field is emptied so its "1.0" prompt shows: the
    /// user can type straight over it, or leave it and get 1.0.
    ///
    /// Deliberately unconditional. SwiftUI may write the field's old value back
    /// as it takes focus, and running last is what clears that away.
    func beginEditing(_ currency: Currency) {
        anchorCode = currency.code
        anchorText = ""
        untouchedAmount = nil
    }

    /// A keystroke landed in a row.
    func updateText(_ newText: String, for currency: Currency) {
        let sanitized = Self.sanitize(newText)
        // SwiftUI writes a field's own value back to its binding when the field
        // takes focus. That isn't the user typing, and acting on it would throw
        // away the exact amount sitting behind the rounded text.
        guard currency.code != anchorCode || sanitized != anchorText else { return }

        anchorCode = currency.code
        anchorText = sanitized
        untouchedAmount = nil   // from here the typed text is the truth
    }

    /// The amount field lost focus, or the user tapped Done.
    ///
    /// Typing 1 used to be how a row became the main currency. Now the user
    /// taps the row instead, and the only field is the main currency's own.
    func commitEditing(for currency: Currency) {
        guard currency.code == anchorCode else { return }
        let amount = anchorAmount
        anchorText = Self.editText(amount)   // tidy "0012" into "12", and "" into "1"
        untouchedAmount = amount             // keep precision the rounding would drop
    }

    // MARK: - List changes

    /// Move a currency to the top and quote everything else against 1 of it.
    func makeMain(_ currency: Currency) {
        anchorCode = currency.code
        anchorText = "1"
        untouchedAmount = nil
        guard let index = currencies.firstIndex(of: currency), index != 0 else { return }
        currencies.move(fromOffsets: IndexSet(integer: index), toOffset: 0)
    }

    /// Add a currency to the bottom of the list.
    func add(_ currency: Currency) {
        guard !currencies.contains(where: { $0.code == currency.code }) else { return }
        currencies.append(currency)
    }

    /// Reorder after a drag. `offsets`/`destination` come straight from the
    /// List, so this is just the array's own move.
    func move(from offsets: IndexSet, to destination: Int) {
        currencies.move(fromOffsets: offsets, toOffset: destination)
    }

    /// Remove one currency, wherever it sits. The add sheet's toggles use this.
    func remove(_ currency: Currency) {
        guard let index = currencies.firstIndex(where: { $0.code == currency.code }) else { return }
        remove(at: IndexSet(integer: index))
    }

    func remove(at offsets: IndexSet) {
        let removingAnchor = offsets.contains { currencies[$0].code == anchorCode }
        currencies.remove(atOffsets: offsets)
        // If the anchor itself was removed, fall back to 1 of the new main currency.
        if removingAnchor, let main = currencies.first {
            makeMain(main)
        }
    }

    // MARK: - Number text

    private static let decimalSeparator = Locale.current.decimalSeparator ?? "."
    private static let groupingSeparator = Locale.current.groupingSeparator ?? ","

    /// Keep digits and at most one decimal separator.
    static func sanitize(_ text: String) -> String {
        var result = ""
        var hasSeparator = false
        for character in text.replacingOccurrences(of: groupingSeparator, with: "") {
            if character.isNumber {
                result.append(character)
            } else if character == "." || character == "," , !hasSeparator {
                hasSeparator = true
                result.append(decimalSeparator)
            }
        }
        return result
    }

    static func parse(_ text: String) -> Decimal? {
        let normalized = text
            .replacingOccurrences(of: groupingSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        return Decimal(string: normalized)
    }

    /// For rows the user isn't editing: grouped, e.g. "1,234.5".
    static func displayText(_ amount: Decimal) -> String {
        displayFormatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    /// For the row the user is editing: no grouping, so it stays re-parseable.
    static func editText(_ amount: Decimal) -> String {
        editFormatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    /// For rates rather than amounts. Up to 3 decimal places like everything
    /// else, except below 1, where 3 significant digits stop a small rate from
    /// rounding away: 1 TRY shows as 0.0205 USD rather than 0.02, and 1 LBP
    /// as 0.0000112 rather than 0.
    static func rateText(_ rate: Decimal) -> String {
        let formatter = rate < 1 ? smallRateFormatter : displayFormatter
        return formatter.string(from: rate as NSDecimalNumber) ?? "0"
    }

    private static let displayFormatter = makeFormatter(grouping: true)
    private static let editFormatter = makeFormatter(grouping: false)

    private static let smallRateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 3
        return formatter
    }()

    private static func makeFormatter(grouping: Bool) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = grouping
        return formatter
    }
}
