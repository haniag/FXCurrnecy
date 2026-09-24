//
//  ContentView.swift
//  oumleh
//
//  Created by hani on 9/21/26.
//

import SwiftUI

/// The main screen: the user's currencies, converted live against whichever one
/// they're typing into.
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
            List {
                ForEach(model.currencies) { currency in
                    CurrencyRowView(
                        currency: currency,
                        text: amountBinding(for: currency),
                        isMain: currency.code == model.mainCode,
                        focusedCode: $focusedCode
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                }
                .onMove { from, to in
                    model.move(from: from, to: to)
                    orderVersion += 1
                }
                .onDelete { model.remove(at: $0) }
            }
            // Rebuilt from scratch after each drag. List applies a drop to its
            // own rows AND again when our array changes, landing one position
            // out; a new identity throws those rows away and re-reads the array.
            .id(orderVersion)
            // iOS 26: softens the cards as they pass under the toolbar, and
            // under the footer — which is now tall enough on a failure that a
            // card would otherwise read straight through the text.
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .listStyle(.plain)
            // Hidden so the gradient below shows through the rows.
            .scrollContentBackground(.hidden)
            .background(LinearGradient.screen.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
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
            .refreshable { await model.refreshRates() }
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
    }

    /// The bottom of the screen: what the rates are doing, or why they aren't.
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
                    ProgressView().controlSize(.small)
                    // A first run has nothing on screen to update yet.
                    Text(model.hasRates ? "Updating rates…" : "Getting rates…")
                }
            case .loaded:
                Text("Rates from \(quotedAtText)")
            case .failed(let reason):
                failureFooter(reason)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        // The footer sits over the list, not beside it, and on a failure it's
        // three lines tall — enough to land on the last card. The thinnest
        // material keeps the text readable while letting the gradient's colour
        // through; a heavier one reads as a grey strip pasted over the tint.
        .background(.ultraThinMaterial)
    }

    /// Why the refresh failed, and a way to try again.
    ///
    /// Pull-to-refresh already retries, but it isn't discoverable and it's the
    /// one thing a stuck user needs, so it gets a button of its own.
    private func failureFooter(_ reason: String) -> some View {
        VStack(spacing: 6) {
            Label(reason, systemImage: "exclamationmark.triangle")
                .multilineTextAlignment(.center)

            // Said plainly, because the rows above still show numbers and
            // nothing else on screen marks them as old ones.
            if model.hasRates {
                Text("Showing rates from \(quotedAtText)")
            }

            Button("Try Again") {
                Task { await model.refreshRates() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
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

    /// Reads through to the model, so every row re-renders from one amount.
    private func amountBinding(for currency: Currency) -> Binding<String> {
        Binding(
            get: { model.displayText(for: currency) },
            set: { newValue in
                // Only the row the user is actually in may change the amount;
                // the other rows are read-only views of it.
                guard focusedCode == currency.code else { return }
                model.updateText(newValue, for: currency)
            }
        )
    }

    /// Commit the row we left, and carry its value into the row we entered.
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
