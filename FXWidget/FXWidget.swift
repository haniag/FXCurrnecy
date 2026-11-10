//
//  FXWidget.swift
//  FXWidget
//

import SwiftUI
import WidgetKit

/// The home-screen widget: the user's main currency and what one of it buys
/// in the next few on their list.
///
/// It makes no network calls of its own. The app saves the list and the last
/// rates into the shared app group (`SettingsStore`) and asks the widget to
/// redraw whenever either changes, so the widget always shows what the app
/// last showed, with the time those rates were quoted.
@main
struct FXWidgetBundle: WidgetBundle {
    var body: some Widget {
        RatesWidget()
    }
}

struct RatesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RatesWidget", provider: RatesTimelineProvider()) { entry in
            RatesWidgetView(entry: entry)
                .containerBackground(Color.paper, for: .widget)
        }
        .configurationDisplayName("Rates")
        .description("Your main currency against the others on your list.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline

/// What one drawing of the widget needs, worked out ahead of time.
struct RatesEntry: TimelineEntry {
    let date: Date
    /// The main currency, or nil when the list is empty.
    let main: Currency?
    /// The currencies below it, each with one main unit converted: "0.872".
    let rows: [Row]
    /// When the rates were quoted, or nil when there are none saved yet.
    let quotedAt: Date?

    struct Row: Identifiable {
        let currency: Currency
        /// Nil when the saved rates don't carry this currency.
        let amount: String?
        var id: String { currency.code }
    }

    /// The most rows either size has room for.
    static let maxRows = 3
}

extension RatesEntry {
    /// Built from whatever the app last saved.
    static func saved(in store: SettingsStore = SettingsStore(), at date: Date = .now) -> RatesEntry {
        let currencies = store.loadCurrencies() ?? Currency.starterList
        let snapshot = store.loadSnapshot()
        return RatesEntry(date: date, currencies: currencies, snapshot: snapshot)
    }

    init(date: Date, currencies: [Currency], snapshot: RatesSnapshot?) {
        let main = currencies.first
        let rates = snapshot?.rates ?? [:]
        let mainRate = main.flatMap { rates[$0.code] }

        self.date = date
        self.main = main
        self.quotedAt = snapshot?.quotedAt
        self.rows = currencies.dropFirst().prefix(Self.maxRows).map { currency in
            var amount: String?
            if let rate = rates[currency.code], let mainRate, mainRate != 0 {
                amount = NumberText.displayText(rate / mainRate)
            }
            return Row(currency: currency, amount: amount)
        }
    }

    /// Stand-in figures for the widget gallery, where there's no saved list.
    static let placeholder = RatesEntry(
        date: .now,
        currencies: [
            Currency(code: "USD", name: "US Dollar"),
            Currency(code: "EUR", name: "Euro"),
            Currency(code: "GBP", name: "British Pound"),
            Currency(code: "JOD", name: "Jordanian Dinar"),
        ],
        snapshot: RatesSnapshot(
            rates: ["USD": 1, "EUR": 0.872, "GBP": 0.748, "JOD": 0.709],
            quotedAt: .now
        )
    )
}

struct RatesTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RatesEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (RatesEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .saved())
    }

    /// A single entry that never expires: the figures only change when the
    /// app fetches or the list is edited, and the app reloads the widget then.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RatesEntry>) -> Void) {
        completion(Timeline(entries: [.saved()], policy: .never))
    }
}

// MARK: - Views

struct RatesWidgetView: View {
    let entry: RatesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let main = entry.main {
                table(main: main)
            } else {
                message("Open FX and tap + to add a currency.")
            }
        }
        .foregroundStyle(Color.ink)
        // The design is pinned light, like the app.
        .environment(\.colorScheme, .light)
    }

    private func table(main: Currency) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // The main currency, marked by the same terracotta edge as in the app.
            HStack(spacing: 8) {
                Rectangle().fill(Color.terracotta).frame(width: 4, height: 18)
                Text("1 \(main.code)")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                if showsNames {
                    Text(main.name)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 8)

            if entry.rows.isEmpty {
                Spacer(minLength: 0)
                Text("Add more currencies in FX to see them here.")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                Spacer(minLength: 0)
            } else {
                ForEach(entry.rows) { row in
                    Rectangle().fill(Color.hairline).frame(height: 1)
                    rowView(row)
                        .frame(maxHeight: .infinity)
                }
            }

            footer
        }
    }

    private func rowView(_ row: RatesEntry.Row) -> some View {
        HStack(spacing: 8) {
            Text(row.currency.code)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
            if showsNames {
                Text(row.currency.name)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(row.amount ?? "—")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .combine)
    }

    /// How fresh the figures are, in the same small capitals as the app's top bar.
    private var footer: some View {
        Group {
            if let quotedAt = entry.quotedAt {
                Text("As of \(quotedAtText(quotedAt))")
            } else {
                Text("Open FX to get rates")
            }
        }
        .font(.system(size: 9, weight: .semibold))
        .tracking(1)
        .textCase(.uppercase)
        .foregroundStyle(Color.inkSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.top, 6)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Only the wide widget has room for names beside the codes.
    private var showsNames: Bool { family != .systemSmall }

    /// The time alone for today's rates, the date too for older ones — the
    /// same rule as the app, since a bare "15:03" reads as this afternoon.
    private func quotedAtText(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Previews

#if DEBUG

#Preview("Small", as: .systemSmall) {
    RatesWidget()
} timeline: {
    RatesEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    RatesWidget()
} timeline: {
    RatesEntry.placeholder
    RatesEntry(date: .now, currencies: [Currency(code: "USD", name: "US Dollar")], snapshot: nil)
}

#endif
