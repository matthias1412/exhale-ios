import SwiftUI

/// The price the user actually pays, typed by them.
///
/// Tappable rather than stepper-only: someone in Reykjavík paying 1,890 kr a
/// pack should not have to press + a hundred times, and we deliberately hold no
/// table of what a pack costs where — see `Currencies`.
struct PriceField: View {
    @Binding var amount: Decimal
    let currencyCode: String

    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            // The visible figure, formatted in the user's currency.
            Text(amount > 0 ? amount.currencyString(currencyCode) : placeholder)
                .font(.spaceGrotesk(38, weight: .bold, relativeTo: .title))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .foregroundStyle(amount > 0 ? Palette.textPrimary : Palette.textFaint)

            // An invisible field on top so the keyboard can drive it.
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .focused($focused)
                .opacity(0.001)
                // A decimal pad has no return key. Without this there was no
                // way to dismiss the keyboard at all — it covered the screen
                // and the app was unreachable behind it.
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focused = false }
                            .font(.spaceGrotesk(15, weight: .bold))
                    }
                }
                .accessibilityLabel("Price")
                .accessibilityValue(amount > 0 ? amount.currencyString(currencyCode) : "not set")
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(focused ? Palette.accent : Palette.textPrimary.opacity(0.15))
                .frame(height: 1.5)
                .offset(y: 8)
        }
        .animation(.snappy(duration: 0.15), value: focused)
    }

    /// Just the currency symbol. It used to be the formatted zero with every
    /// digit replaced by an em dash, which said the same thing in a character
    /// the rest of the app no longer uses.
    private var placeholder: String {
        Decimal(0).currencyString(currencyCode)
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.,  "))
            .joined()
    }

    private var text: Binding<String> {
        Binding(
            get: { amount > 0 ? "\(amount)" : "" },
            set: { raw in
                let cleaned = raw.replacingOccurrences(of: ",", with: ".")
                    .filter { $0.isNumber || $0 == "." }
                amount = Decimal(string: cleaned) ?? 0
            }
        )
    }
}
