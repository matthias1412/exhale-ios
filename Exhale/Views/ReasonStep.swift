import SwiftUI

/// Onboarding step 2 — why.
///
/// Multi-select, because people rarely have one reason, but the first tap is
/// the one that personalises the app. Nothing here is optional-feeling: the
/// answer visibly changes which tab opens and what the craving screen says.
struct ReasonStep: View {
    @Environment(AppModel.self) private var model
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Why now?")
                .font(.spaceGrotesk(30, weight: .bold, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)

            Text("Pick as many as are true. We'll hand the first one back to you when it's hard.")
                .font(.spaceGrotesk(14))
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(QuitReason.allCases) { reason in
                    ReasonRow(
                        reason: reason,
                        rank: model.state.reasons.firstIndex(of: reason)
                    ) {
                        toggle(reason)
                    }
                }
            }
            .padding(.top, 10)

            if model.state.reasons.contains(.someone) {
                TextField("Their name, if you like", text: nameBinding)
                    .textFieldStyle(.plain)
                    .font(.spaceGrotesk(15))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Palette.cardBorder, lineWidth: 1.5)
                    )
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .transition(.opacity)
                    .accessibilityHint("Optional. Used only on your own device.")
            }
        }
        .padding(.top, 34)
        .animation(.snappy(duration: 0.2), value: model.state.reasons)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { model.state.reasonName ?? "" },
            set: { model.state.reasonName = $0.isEmpty ? nil : $0 }
        )
    }

    private func toggle(_ reason: QuitReason) {
        Feedback.selection()
        if let index = model.state.reasons.firstIndex(of: reason) {
            model.state.reasons.remove(at: index)
            if reason == .someone { model.state.reasonName = nil }
        } else {
            model.state.reasons.append(reason)
        }
    }
}

struct ReasonRow: View {
    let reason: QuitReason
    /// Position in the selection order; 0 means it's the one that personalises.
    let rank: Int?
    let toggle: () -> Void

    private var isSelected: Bool { rank != nil }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reason.title)
                        .font(.spaceGrotesk(16, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(reason.subtitle)
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.textMuted)
                }

                Spacer(minLength: 0)

                if rank == 0 {
                    Text("MAIN")
                        .font(.spaceGrotesk(9, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.accent))
                }

                Circle()
                    .strokeBorder(isSelected ? Palette.accent : Palette.stepperBorder,
                                  lineWidth: 2)
                    .background(Circle().fill(isSelected ? Palette.accent : .clear))
                    .frame(width: 20, height: 20)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Palette.accent.opacity(0.10) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? Palette.accent : Palette.cardBorder,
                                    lineWidth: 1.5)
                    )
            )
        }
        .accessibilityLabel("\(reason.title), \(reason.subtitle)")
        .accessibilityValue(rank == 0 ? "main reason" : (isSelected ? "selected" : "not selected"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
