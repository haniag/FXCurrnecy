//
//  AddCurrencyView.swift
//  oumleh
//

import SwiftUI

/// The sheet behind the "+" button: search, then pick a currency to add.
///
/// The list comes from Xe, so it only ever offers currencies Xe can actually
/// quote a rate for.
struct AddCurrencyView: View {
    /// Codes already on the main screen, so they aren't offered twice.
    let existingCodes: Set<String>
    let onAdd: (Currency) -> Void

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

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add Currency")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .task { await loadCurrencies() }
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

    private func list(of currencies: [Currency]) -> some View {
        let results = results(in: currencies)
        return List(results) { currency in
            Button {
                onAdd(currency)
                dismiss()
            } label: {
                row(for: currency)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search by code or name")
        .overlay {
            if results.isEmpty { emptyState }
        }
    }

    private func results(in currencies: [Currency]) -> [Currency] {
        let available = currencies.filter { !existingCodes.contains($0.code) }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return available }
        return available.filter {
            $0.code.localizedCaseInsensitiveContains(query)
                || $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func row(for currency: Currency) -> some View {
        HStack(spacing: 14) {
            FlagIcon(countryCode: currency.countryCode, diameter: 32)

            // "AED - Emirati Dirham". The code keeps the monospaced face used on
            // the main screen, so every name starts at the same x position.
            Text("\(Text(currency.code).font(.system(size: 16, weight: .bold, design: .monospaced))) - \(currency.name)")
                .font(.system(size: 16))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            // Only currencies with a glyph of their own get one.
            if let symbol = CurrencyCatalog.symbol(for: currency.code) {
                Text(symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(.rect)
    }

    // MARK: - The other states

    @ViewBuilder
    private var emptyState: some View {
        if searchText.isEmpty {
            ContentUnavailableView(
                "Nothing Left to Add",
                systemImage: "checkmark.circle",
                description: Text("Every currency is already on your list.")
            )
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }

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

// MARK: - Previews

/// Stand-in rows, so the previews don't depend on the network being up.
private let sampleCurrencies = [
    Currency(code: "AED", name: "Emirati Dirham"),
    Currency(code: "BAM", name: "Bosnia-Herzegovina Convertible Mark"),
    Currency(code: "EUR", name: "Euro"),
    Currency(code: "GBP", name: "British Pound"),
    Currency(code: "JOD", name: "Jordanian Dinar"),
    Currency(code: "JPY", name: "Japanese Yen"),
    Currency(code: "USD", name: "US Dollar"),
]

#Preview("Loaded") {
    AddCurrencyView(existingCodes: ["USD", "EUR"]) { _ in } load: {
        sampleCurrencies
    }
}

#Preview("Loading") {
    AddCurrencyView(existingCodes: []) { _ in } load: {
        try await Task.sleep(for: .seconds(60))   // never finishes: holds the spinner on screen
        return []
    }
}

#Preview("Failed") {
    AddCurrencyView(existingCodes: []) { _ in } load: {
        throw URLError(.notConnectedToInternet)
    }
}

#Preview("Live") {
    AddCurrencyView(existingCodes: ["USD"]) { _ in }
}
