import SwiftUI
import AppleAppLabUI
#if os(iOS)
import UIKit
#endif

/// DESIGN_LIQUID.md § "Sheet de captura/edición de línea" — decisión del usuario que
/// reemplaza el patrón anterior de fila inline por completo: tocar "+" en INCOME/EXPENSES o
/// tocar una línea existente ya no transforma nada in-place, abre este bottom sheet nativo,
/// precargado con los valores existentes cuando edita. El mismo componente sirve para crear
/// y para editar.
struct LineCaptureSheet: View {
    /// `nil` → creando una línea nueva de `kind`. No-nil → editando esa línea existente.
    let editingLine: LineItem?
    let kind: LineKind
    let onSave: (_ title: String, _ amount: Decimal, _ currency: Currency) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var title: String
    @State private var amountText: String
    @State private var currency: Currency
    @State private var didAttemptSave = false

    @FocusState private var focusedField: Field?
    private enum Field { case description, amount }

    init(editingLine: LineItem?, kind: LineKind, onSave: @escaping (String, Decimal, Currency) -> Void) {
        self.editingLine = editingLine
        self.kind = kind
        self.onSave = onSave
        _title = State(initialValue: editingLine?.title ?? "")
        // Starts blank (placeholder "0.00") instead of pre-filled with "0" — ya corregido
        // antes (bug de concatenación en el primer keystroke), no romperlo.
        _amountText = State(initialValue: (editingLine.map { $0.amount == 0 ? "" : $0.amount.twoDecimalString }) ?? "")
        _currency = State(initialValue: editingLine?.currency ?? .usd)
    }

    private var amount: Decimal {
        Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private var isTitleEditable: Bool {
        editingLine?.origin != .carryOver
    }

    private var carryOverHint: String? {
        editingLine?.origin == .carryOver ? "No se puede editar porque es arrastrado del mes anterior" : nil
    }

    private var isValid: Bool {
        PeriodCoordinator.isValidManualLine(title: title, amount: amount)
    }

    private var isLargeAccessibilitySize: Bool { dynamicTypeSize >= .accessibility1 }

    private var navigationTitleText: String {
        guard let editingLine else { return kind == .income ? "Agregar ingreso" : "Agregar gasto" }
        return editingLine.origin == .carryOver ? "Latest Month" : "Editar línea"
    }

    /// Origin context shown only while editing a non-manual line — the row itself no longer
    /// shows an origin icon, so this sheet is where that information still surfaces visually.
    private var originContext: String? {
        guard let editingLine, editingLine.origin != .manual else { return nil }
        switch editingLine.origin {
        case .manual: return nil
        case .recurring: return "Generado por: recurrente"
        case .subscription: return "Generado por: " + (editingLine.isHomeService ? "servicio del hogar" : "suscripción")
        case .loan: return "Generado por: préstamo"
        case .investment: return "Generado por: inversión"
        case .carryOver: return "Generado por: quincena anterior"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(navigationTitleText)
                .font(.title3.weight(.semibold))
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Descripción")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isTitleEditable {
                    LabTextField(placeholder: "Descripción", text: $title, config: PatternConfig(accentColor: .accentColor))
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        #endif
                        .focused($focusedField, equals: .description)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .amount }
                } else {
                    Text(title)
                        .foregroundStyle(.secondary)
                        .accessibilityHint(carryOverHint ?? "")
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Monto")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("0.00", text: $amountText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .textFieldStyle(.roundedBorder)
                        .disabled(!isTitleEditable)
                        .focused($focusedField, equals: .amount)
                        .accessibilityHint(carryOverHint ?? "")

                    Picker("Moneda", selection: $currency) {
                        Text("USD").tag(Currency.usd)
                        Text("MXN").tag(Currency.mxn)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                    .disabled(!isTitleEditable)
                    .accessibilityHint(carryOverHint ?? "")
                }
            }

            if let originContext {
                Text(originContext)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // "Escribe una descripción y un monto mayor a 0" — SOLO tras un intento fallido
            // de confirmar, nunca se anticipa el error en reposo.
            if didAttemptSave && !isValid {
                Text("Escribe una descripción y un monto mayor a 0")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 12)

            actionButtons
        }
        .padding(20)
        .onAppear {
            // Foco inicial automático en Descripción, sin que el usuario tenga que tocar el
            // campo — DESIGN_LIQUID.md, requisito de accesibilidad además de conveniencia.
            if isTitleEditable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    focusedField = .description
                }
            }
        }
        // "Fondo Frost del tema, no Liquid Glass" — excepción documentada explícitamente para
        // esta pantalla.
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(20)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color("AppBackgroundSecondary"))
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var actionButtons: some View {
        let cancelButton = Button("Cancelar") { dismiss() }
            .buttonStyle(.glass)
            .frame(maxWidth: .infinity)

        let saveButton = Button("Listo") { attemptSave() }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
            .disabled(!isTitleEditable)
            .frame(maxWidth: .infinity)

        // Bug corregido (Jonny): "Cancelar" se truncaba en 3 líneas por falta de ancho en la
        // fila corta — cada botón usa `.frame(maxWidth: .infinity)` siempre; a tamaños de
        // Dynamic Type de accesibilidad se apilan verticalmente en vez de lado a lado.
        if isLargeAccessibilitySize {
            VStack(spacing: 12) {
                saveButton
                cancelButton
            }
        } else {
            HStack(spacing: 12) {
                cancelButton
                saveButton
            }
        }
    }

    private func attemptSave() {
        guard isTitleEditable else { dismiss(); return }
        guard isValid else {
            didAttemptSave = true
            #if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            #endif
            return
        }
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        onSave(title, amount, currency)
        dismiss()
    }
}
