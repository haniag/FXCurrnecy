//
//  AddCurrencyView.swift
//  oumleh
//

import SwiftUI

/// The sheet behind the "+" button: a checklist of every currency. Tap one to
/// add it to the main screen, tap it again to take it off.
///
/// The list comes from Xe, so it only ever offers currencies Xe can actually
/// quote a rate for.
struct AddCurrencyView: View {
    /// Codes on the main screen right now. Fresh each time the list changes,
    /// since the sheet is redrawn with the screen behind it.
    let existingCodes: Set<String>
    /// The main currency, which the rate column is quoted in.
    let mainCode: String
    /// One of the main currency in the given one, e.g. "3.673", or nil with no
    /// rate to show.
    var rateText: (Currency) -> String? = { _ in nil }
    let onAdd: (Currency) -> Void
    let onRemove: (Currency) -> Void

    /// Where the list comes from. Swappable so the previews below can show every
    /// state without going near the network.
    var load: () async throws -> [Currency] = { try await XeCurrencyService.shared.currencies() }

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var phase = Phase.loading

    /// What the sheet is doing: still fetching, showing the list, or explaining
    /// why it can't.
    enum Phase {
        case loading
        case loaded([Currency])
        case failed(String)
    }

    /// Shown first, above the full list. A short hand-picked set rather than
    /// anything clever: the currencies most people in the region reach for.
    static let popularCodes = ["EUR", "GBP", "AED", "SAR", "EGP", "JPY", "CAD", "CHF"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Add a currency")
                    .font(.system(size: 32, weight: .semibold))
                    .padding(.horizontal, 20)

                searchField
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .foregroundStyle(Color.ink)
            .background(Color.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .task { await loadCurrencies() }
        }
        .tint(Color.ink)
        .presentationBackground(Color.paper)
    }

    /// A plain field with a rule under it, in keeping with the rest of the page.
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkSecondary)
            TextField(
                "Search",
                text: $searchText,
                prompt: Text("Code, name or country").foregroundStyle(Color.inkSecondary)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.ink).frame(height: 1.5)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView("Loading currencies…")
        case .loaded(let currencies):
            list(of: currencies)
        case .failed(let message):
            failureState(message)
        }
    }

    // MARK: - The list

    private var query: String { searchText.trimmingCharacters(in: .whitespaces) }

    private func list(of currencies: [Currency]) -> some View {
        let results = results(in: currencies)
        return List {
            if query.isEmpty {
                let popular = Self.popularCodes.compactMap { code in
                    currencies.first { $0.code == code }
                }
                Section {
                    ForEach(popular) { row(for: $0) }
                } header: {
                    sectionHeader("Popular", showsRates: popular.contains { rateText($0) != nil })
                }
                Section {
                    ForEach(currencies) { row(for: $0) }
                } header: {
                    sectionHeader("All currencies", showsRates: currencies.contains { rateText($0) != nil })
                }
            } else {
                ForEach(results) { row(for: $0) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if !query.isEmpty && results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    /// Matches the code, the name, or the country: "jordan" finds JOD.
    private func results(in currencies: [Currency]) -> [Currency] {
        guard !query.isEmpty else { return currencies }
        return currencies.filter {
            $0.code.localizedCaseInsensitiveContains(query)
                || $0.name.localizedCaseInsensitiveContains(query)
                || (Locale.current.localizedString(forRegionCode: $0.countryCode)?
                    .localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// "POPULAR" on the left and, once there are rates, "PER 1 USD" over the
    /// rate column on the right.
    private func sectionHeader(_ title: String, showsRates: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if showsRates {
                Text("Per 1 \(mainCode)")
                    // Lines up with the rates: the toggle and its gap sit to
                    // their right.
                    .padding(.trailing, 52)
            }
        }
        .ledgerLabel()
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color.paper)
        .listRowInsets(EdgeInsets())
    }

    private func row(for currency: Currency) -> some View {
        let isOnList = existingCodes.contains(currency.code)
        return Button {
            if isOnList { onRemove(currency) } else { onAdd(currency) }
        } label: {
            HStack(spacing: 14) {
                FlagIcon(countryCode: currency.countryCode, diameter: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(currency.code)
                        .font(.rowCode)
                        .tracking(0.8)
                    Text(isOnList ? "\(currency.name) · On your list" : currency.name)
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let rate = rateText(currency) {
                    Text(rate)
                        .font(.listRate)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                ToggleMark(isOn: isOnList)
                    .padding(.leading, 8)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 58)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOnList ? .isSelected : [])
        .accessibilityHint(isOnList ? "Removes it from your list" : "Adds it to your list")
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 16))
        .listRowSeparatorTint(Color.hairline)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    // MARK: - The other states

    private func failureState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't Load Currencies", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await loadCurrencies() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Loading

    private func loadCurrencies() async {
        phase = .loading
        do {
            phase = .loaded(try await load())
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// The circle at the end of each row: an outlined "+" when the currency can be
/// added, a filled check when it's already on the list.
private struct ToggleMark: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            if isOn {
                Circle().fill(Color.terracotta)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.paper)
            } else {
                Circle().strokeBorder(Color.ink.opacity(0.3), lineWidth: 1.5)
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

/// Stand-in rows, so the previews don't depend on the network being up.
private let sampleCurrencies = [
    Currency(code: "AED", name: "Emirati Dirham"),
    Currency(code: "BAM", name: "Bosnia-Herzegovina Convertible Mark"),
    Currency(code: "CAD", name: "Canadian Dollar"),
    Currency(code: "CHF", name: "Swiss Franc"),
    Currency(code: "EGP", name: "Egyptian Pound"),
    Currency(code: "EUR", name: "Euro"),
    Currency(code: "GBP", name: "British Pound"),
    Currency(code: "JOD", name: "Jordanian Dinar"),
    Currency(code: "JPY", name: "Japanese Yen"),
    Currency(code: "SAR", name: "Saudi Riyal"),
    Currency(code: "USD", name: "US Dollar"),
]

/// Sample rates against 1 USD, formatted the way the app formats them.
private func sampleRate(_ currency: Currency) -> String? {
    Currency.sampleRates[currency.code].map(ConverterViewModel.rateText)
}

#Preview("Loaded") {
    @Previewable @State var existing: Set<String> = ["USD", "EUR", "GBP"]

    AddCurrencyView(
        existingCodes: existing,
        mainCode: "USD",
        rateText: sampleRate,
        onAdd: { existing.insert($0.code) },
        onRemove: { existing.remove($0.code) }
    ) {
        sampleCurrencies
    }
}

#Preview("Loading") {
    AddCurrencyView(existingCodes: [], mainCode: "USD", onAdd: { _ in }, onRemove: { _ in }) {
        try await Task.sleep(for: .seconds(60))   // never finishes: holds the spinner on screen
        return []
    }
}

#Preview("Failed") {
    AddCurrencyView(existingCodes: [], mainCode: "USD", onAdd: { _ in }, onRemove: { _ in }) {
        throw URLError(.notConnectedToInternet)
    }
}

#Preview("Live") {
    AddCurrencyView(existingCodes: ["USD"], mainCode: "USD", onAdd: { _ in }, onRemove: { _ in })
}
