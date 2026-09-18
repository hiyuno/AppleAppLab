import SwiftUI
import SwiftData
import AppleAppLabUI

/// Ajustes → Preferencias → "Categorías de suscripciones". User feedback: "en settings agrega
/// que podamos agregar las categorías que queramos" — `SubscriptionCategory` (fixed enum) is
/// replaced by this user-editable list (`SubscriptionCategoryItem`), seeded once on first
/// launch (`RootView`) with the 7 original cases. Same list-management pattern as
/// `CreditCardsView`: `@Query`, swipe-to-delete, `+` toolbar button opening an add/edit sheet.
struct SubscriptionCategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SubscriptionCategoryItem.sortOrder) private var categories: [SubscriptionCategoryItem]
    @Query private var allSubscriptions: [Subscription]

    @State private var editingCategory: SubscriptionCategoryItem?
    @State private var isPresentingNew = false
    @State private var categoryPendingDelete: SubscriptionCategoryItem?
    @State private var isShowingInUseAlert = false

    var body: some View {
        Group {
            if categories.isEmpty {
                LabEmptyState(
                    icon: "tag",
                    title: "Sin categorías todavía",
                    message: "Agrega una categoría para clasificar tus suscripciones",
                    config: PatternConfig(accentColor: .accentColor)
                )
            } else {
                List {
                    ForEach(categories) { category in
                        Button {
                            editingCategory = category
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.iconName)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28)
                                Text(category.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                requestDelete(category)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            Button {
                                editingCategory = category
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Categorías de suscripciones")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingNew = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Agregar categoría")
            }
        }
        .sheet(isPresented: $isPresentingNew) {
            SubscriptionCategoryEditSheet(category: nil, nextSortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1)
        }
        .sheet(item: $editingCategory) { category in
            SubscriptionCategoryEditSheet(category: category, nextSortOrder: category.sortOrder)
        }
        .alert("Categoría en uso", isPresented: $isShowingInUseAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Esta categoría tiene suscripciones asignadas. Reasígnalas a otra categoría antes de eliminarla.")
        }
    }

    /// Decisión (2026-09-17): bloquear el borrado en vez de reasignar en silencio — reasignar
    /// automáticamente a una categoría "fallback" cambiaría el dato del usuario sin que lo
    /// pida explícitamente. `categoryRaw` es solo un string (no hay relación forzada), así
    /// que nada se rompe si el usuario prefiere editar el nombre en vez de borrar.
    private func requestDelete(_ category: SubscriptionCategoryItem) {
        let isInUse = allSubscriptions.contains { $0.categoryRaw == category.name }
        if isInUse {
            isShowingInUseAlert = true
        } else {
            context.delete(category)
            try? context.save()
        }
    }
}

/// Curated SF Symbol set for the icon picker — small and finance/subscription-relevant rather
/// than exhaustive, same spirit as the day-of-month pill in `CreditCardsView` (pick a compact
/// control over reproducing the entire system symbol catalog).
private let subscriptionCategoryIconChoices = [
    "tag", "wrench.and.screwdriver", "play.tv", "house", "briefcase", "person",
    "paintpalette", "chart.line.uptrend.xyaxis", "gamecontroller", "book",
    "heart", "cart", "car", "airplane", "graduationcap", "pawprint",
    "dumbbell", "music.note", "camera", "wifi",
]

private struct SubscriptionCategoryEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let category: SubscriptionCategoryItem?
    let nextSortOrder: Int

    @State private var name: String
    @State private var iconName: String

    init(category: SubscriptionCategoryItem?, nextSortOrder: Int) {
        self.category = category
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: category?.name ?? "")
        _iconName = State(initialValue: category?.iconName ?? "tag")
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabTextField(placeholder: "Nombre", text: $name, config: PatternConfig(accentColor: .accentColor))
                }

                Section("Ícono") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(subscriptionCategoryIconChoices, id: \.self) { choice in
                            Button {
                                iconName = choice
                            } label: {
                                Image(systemName: choice)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(iconName == choice ? Color.white : Color.primary)
                                    .background {
                                        if iconName == choice {
                                            Circle().fill(Color.accentColor)
                                        } else {
                                            Circle().fill(.fill.tertiary)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(choice)
                            .accessibilityAddTraits(iconName == choice ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "Nueva categoría" : "Editar categoría")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!isFormValid)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let category {
            category.name = trimmedName
            category.iconName = iconName
        } else {
            let newCategory = SubscriptionCategoryItem(name: trimmedName, iconName: iconName, sortOrder: nextSortOrder)
            context.insert(newCategory)
        }
        try? context.save()
        dismiss()
    }
}
