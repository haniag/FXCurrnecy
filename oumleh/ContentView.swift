//
//  ContentView.swift
//  oumleh
//
//  Created by hani on 9/21/26.
//

import SwiftUI

/// The main screen, laid out like a printed rates table: the main currency and
/// its amount at the top, every other currency converted from it below.
struct ContentView: View {
    @State private var model: ConverterViewModel
    @State private var isAddingCurrency = false
    @FocusState private var focusedCode: String?
    /// Bumped after every drag. See the `.id` on the List below.
    @State private var orderVersion = 0

    /// The app builds its own model: the saved list from `SettingsStore`, and
    /// live rates from `LiveRatesProvider` — which stays quiet until its
    /// endpoint and key are filled in. The previews below hand one in instead,
    /// so each state can be seen without a network or the real saved list.
    init(model: ConverterViewModel = ConverterViewModel(ratesProvider: LiveRatesProvider())) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let main = model.currencies.first {
                    MainCurrencyHeader(
                        currency: main,
                        choices: model.currencies,
                        text: amountBinding(for: main),
                        focusedCode: $focusedCode,
                        onChoose: makeMain
                    )
                    list
                } else {
                    emptyState
                }
            }
            .background(Color.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingCurrency = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add currency")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedCode = nil }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: focusedCode, handleFocusChange)
            .safeAreaInset(edge: .bottom) { statusFooter }
            // The rates for the user's currencies, fetched once on launch.
            .task { await model.refreshRates() }
            .sheet(isPresented: $isAddingCurrency) {
                AddCurrencyView(
                    existingCodes: Set(model.currencies.map(\.code)),
                    onAdd: { currency in
                        model.add(currency)
                        // The new currency wasn't in the last request, so ask again.
                        Task { await model.refreshRates() }
                    }
                )
            }
        }
        .tint(Color.ink)
        // The design's colours are pinned light, so the system's parts (the
        // status bar, the keyboard, menus) are kept light to match. In dark
        // mode they'd otherwise turn dark around a light screen.
        .preferredColorScheme(.light)
    }

    /// Every currency but the main one. Tapping a row makes it the main one;
    /// a long press drags it to a new place; a swipe deletes it.
    private var list: some View {
        List {
            ForEach(model.otherCurrencies) { currency in
                Button {
                    makeMain(currency)
                } label: {
                    LedgerRowView(
                        currency: currency,
                        amount: model.displayText(for: currency),
                        inverseRate: model.inverseRateText(for: currency)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Makes \(currency.name) the main currency")
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowSeparatorTint(Color.hairline)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
            // The list starts below the main currency, so each position here is
            // one less than the same currency's place in the full list.
            .onMove { from, to in
                model.move(from: IndexSet(from.map { $0 + 1 }), to: to + 1)
                orderVersion += 1
            }
            .onDelete { offsets in
                model.remove(at: IndexSet(offsets.map { $0 + 1 }))
            }
        }
        // Rebuilt from scratch after each drag. List applies a drop to its
        // own rows AND again when our array changes, landing one position
        // out; a new identity throws those rows away and re-reads the array.
        .id(orderVersion)
        // iOS 26: softens the rows as they pass under the footer.
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .listStyle(.plain)
        // Hidden so the paper shows through the rows.
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        // Pulling down is the only way to refresh; there's no button for it.
        .refreshable { await model.refreshRates() }
    }

    /// Only reachable by removing every currency.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Currencies", systemImage: "banknote")
        } description: {
            Text("Tap + to add the currencies you want to convert.")
        }
    }

    /// Move `currency` to the top, quoted at 1, with everything else converted
    /// from it. What tapping a row and the header's menu both do.
    private func makeMain(_ currency: Currency) {
        focusedCode = nil
        withAnimation(.snappy) { model.makeMain(currency) }
    }

    /// The bottom of the screen: how fresh the rates are, or why they aren't.
    ///
    /// The list itself is never replaced by a spinner or an error. Adding,
    /// removing and reordering all work without a single rate, so taking the
    /// screen away over a failed fetch would cost more than it explains.
    @ViewBuilder
    private var statusFooter: some View {
        Group {
            switch model.status {
            case .loading:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    // A first run has nothing on screen to update yet.
                    Text(model.hasRates ? "Updating rates…" : "Getting rates…")
                }
                .ledgerLabel()
            case .loaded:
                Text("Rates as of \(quotedAtText)")
                    .ledgerLabel()
            case .failed(let reason):
                failureFooter(reason)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        // Solid paper, so a row scrolling underneath can't show through the text.
        .background(Color.paper)
    }

    /// Why the refresh failed. Pulling the list down tries again, and with no
    /// button for it the footer says so.
    private func failureFooter(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(reason, systemImage: "exclamationmark.triangle")

            // Said plainly, because the rows above still show numbers and
            // nothing else on screen marks them as old ones.
            if model.hasRates {
                Text("Showing rates from \(quotedAtText).")
            }

            Text("Pull down to try again.")
        }
        .font(.footnote)
        .foregroundStyle(Color.inkSecondary)
    }

    /// The quote time as the footer shows it: the time alone when the rates were
    /// struck today, date and time when they weren't. The feed's timestamp can
    /// be hours or days old, and a bare "15:03" would read as this afternoon.
    private var quotedAtText: String {
        let date = model.quotedAt
        return Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Reads through to the model, so the rows re-render from one amount.
    private func amountBinding(for currency: Currency) -> Binding<String> {
        Binding(
            get: { model.displayText(for: currency) },
            set: { newValue in
                // Only the field the user is actually in may change the amount.
                guard focusedCode == currency.code else { return }
                model.updateText(newValue, for: currency)
            }
        )
    }

    /// Commit the amount we left, and start fresh in the one we entered.
    private func handleFocusChange(from oldCode: String?, to newCode: String?) {
        if let oldCode, let currency = model.currency(for: oldCode) {
            withAnimation(.snappy) { model.commitEditing(for: currency) }
        }
        if let newCode, let currency = model.currency(for: newCode) {
            model.beginEditing(currency)
        }
    }
}

// MARK: - Previews

/// Rates already on screen, quoted a moment ago.
#Preview("Loaded") {
    ContentView(model: ConverterViewModel(
        store: .ephemeral(
            currencies: Currency.starterList,
            snapshot: RatesSnapshot(rates: Currency.sampleRates, quotedAt: .now)
        ),
        ratesProvider: SampleRatesProvider()
    ))
}

/// A first run: nothing saved, so every row sits at "—" while the fetch runs.
#Preview("Loading, first run") {
    ContentView(model: ConverterViewModel(
        store: .ephemeral(),
        ratesProvider: StalledRatesProvider()
    ))
}

/// A first run that failed — today's state, with no endpoint or key filled in.
#Preview("Failed, nothing saved") {
    ContentView(model: ConverterViewModel(
        store: .ephemeral(),
        ratesProvider: FailingRatesProvider(error: .notConfigured)
    ))
}

/// A failure with yesterday's rates still on screen: the footer has to say so,
/// or the numbers above read as current.
#Preview("Failed, older rates on screen") {
    ContentView(model: ConverterViewModel(
        store: .ephemeral(
            currencies: Currency.starterList,
            snapshot: RatesSnapshot(
                rates: Currency.sampleRates,
                quotedAt: .now.addingTimeInterval(-90_000)   // ~25 hours ago
            )
        ),
        ratesProvider: FailingRatesProvider(error: .badStatus(401))
    ))
}
