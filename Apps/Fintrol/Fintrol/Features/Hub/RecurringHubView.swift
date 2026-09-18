import SwiftUI
import SwiftData
import AppleAppLabUI

/// "Recurrentes y pagos" — hub of 4 entries (iPhone only; macOS sidebar lists these as
/// direct items instead, DESIGN_LIQUID.md). No "+" of its own: each row pushes to its own
/// list, where the "+" lives.
struct RecurringHubView: View {
    @Query private var recurringItems: [RecurringItem]
    @Query private var subscriptions: [Subscription]
    @Query private var loans: [Loan]
    @Query private var creditCards: [CreditCard]

    private var incomeCount: Int { recurringItems.filter { $0.kind == .income && $0.category != .investment }.count }
    private var expenseCount: Int { recurringItems.filter { $0.kind == .expense && $0.category != .investment }.count }
    private var serviceCount: Int { subscriptions.filter { $0.kind == .service }.count }
    private var subscriptionCount: Int { subscriptions.filter { $0.kind == .subscription }.count }
    private var loanCount: Int { loans.count }
    private var creditCardCount: Int { creditCards.filter(\.isActive).count }
    private var investmentCount: Int { recurringItems.filter { $0.category == .investment }.count }

    var body: some View {
        // Coordinator (2026-09-17): "Gastos recurrentes" moved from "INCOME" to "EXPENSES"
        // (first row there, before Servicios/Suscripciones/Préstamos) — corrects the earlier
        // literal-string grouping (2026-09-15) that put it under INCOME despite being an
        // expense; INCOME now holds only "Ingresos recurrentes". DESIGN_LIQUID.md § Hub
        // updated to match.
        List {
            Section {
                NavigationLink {
                    RecurringListView(kind: .income)
                } label: {
                    row(
                        title: String(localized: "hub_row_recurring_income", defaultValue: "Recurring income"),
                        description: String(localized: "hub_row_recurring_income_desc", defaultValue: "Income that repeats every period, like your salary"),
                        systemImage: "arrow.down.circle",
                        count: incomeCount
                    )
                }
            } header: {
                sectionHeader(String(localized: "hub_section_income", defaultValue: "INCOME"))
            }

            Section {
                NavigationLink {
                    RecurringListView(kind: .expense)
                } label: {
                    row(
                        title: String(localized: "hub_row_recurring_expense", defaultValue: "Recurring expenses"),
                        description: String(localized: "hub_row_recurring_expense_desc", defaultValue: "Expenses that repeat automatically each period"),
                        systemImage: "arrow.up.circle",
                        count: expenseCount
                    )
                }
                NavigationLink {
                    ServicesView()
                } label: {
                    row(
                        title: String(localized: "hub_row_services", defaultValue: "Services"),
                        description: String(localized: "hub_row_services_desc", defaultValue: "Fixed monthly bills — rent, utilities, internet"),
                        systemImage: "house.fill",
                        count: serviceCount
                    )
                }
                NavigationLink {
                    SubscriptionsView()
                } label: {
                    row(
                        title: String(localized: "hub_row_subscriptions", defaultValue: "Subscriptions"),
                        description: String(localized: "hub_row_subscriptions_desc", defaultValue: "Recurring subscriptions — streaming, apps, memberships"),
                        systemImage: "repeat",
                        count: subscriptionCount
                    )
                }
                NavigationLink {
                    LoansView()
                } label: {
                    row(
                        title: String(localized: "hub_row_loans", defaultValue: "Loans"),
                        description: String(localized: "hub_row_loans_desc", defaultValue: "Loans you're paying off or that are being paid to you"),
                        systemImage: "banknote",
                        count: loanCount
                    )
                }
                NavigationLink {
                    CreditCardsView()
                } label: {
                    row(
                        title: String(localized: "hub_row_credit_cards", defaultValue: "Credit Cards"),
                        description: String(localized: "hub_row_credit_cards_desc", defaultValue: "Manage balances, APR, and payment dates"),
                        systemImage: "creditcard.fill",
                        count: creditCardCount
                    )
                }
            } header: {
                sectionHeader(String(localized: "hub_section_expenses", defaultValue: "EXPENSES"))
            }

            Section {
                NavigationLink {
                    InvestmentsView()
                } label: {
                    row(
                        title: String(localized: "hub_row_investments", defaultValue: "Investments"),
                        description: String(localized: "hub_row_investments_desc", defaultValue: "Recurring contributions to your investments"),
                        systemImage: "chart.line.uptrend.xyaxis",
                        count: investmentCount
                    )
                }
            } header: {
                sectionHeader(String(localized: "hub_section_others", defaultValue: "OTHERS"))
            }
        }
        .navigationTitle(String(localized: "hub_title", defaultValue: "Recurring & Payments"))
    }

    // Same header style already used in Ajustes (SettingsView): caption, uppercase, secondary.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
    }

    // Layout: icon, then title + one-line description stacked (description subordinate to
    // title — .caption/.secondary, same family used for the count today). The item count
    // moves to a trailing badge before the chevron so it stays legible without competing
    // with the description for the same line; .tertiary keeps it clearly the least important
    // piece of text in the row. "Regular" density from STYLE_BRIEF.md is preserved — still one
    // row per category, no extra vertical padding added.
    private func row(title: String, description: String, systemImage: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(String(localized: "hub_item_count", defaultValue: "\(count) items"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }
}
