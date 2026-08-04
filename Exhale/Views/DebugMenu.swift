import SwiftUI

/// Five taps on the wordmark. Lets a TestFlight build reach day 1,825 without
/// waiting five years — the prototype's time-travel presets, kept because they
/// are genuinely useful for checking layout on a real device.
struct DebugMenu: View {
    @Environment(AppModel.self) private var model

    private static let presets: [(label: String, day: Int)] = [
        ("Day 1", 1), ("Week 1", 7), ("Month 1", 30), ("90 days", 90),
        ("6 months", 180), ("1 year", 365), ("2 years", 730), ("5 years", 1825)
    ]

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("DEBUG")
                        .font(.spaceGrotesk(13, weight: .bold))
                        .tracking(2.86)
                        .foregroundStyle(Palette.accent)
                    Spacer()
                    Button("Close") { model.debugMenuOpen = false }
                        .font(.spaceGrotesk(14, weight: .bold))
                        .foregroundStyle(Palette.accent)
                }
                .padding(.top, 8)

                SectionLabel("TIME TRAVEL").padding(.top, 24)
                Text("Moves the quit date so the streak reads as chosen. Everything else is derived, so the whole app follows.")
                    .font(.spaceGrotesk(12))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                FlowLayout(spacing: 8) {
                    ForEach(Self.presets, id: \.day) { preset in
                        Button {
                            travel(toDay: preset.day)
                        } label: {
                            Text(preset.label)
                                .font(.spaceGrotesk(13, weight: .bold))
                                .foregroundStyle(isCurrent(preset.day) ? Palette.onAccent : Palette.textMuted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(isCurrent(preset.day) ? Palette.accent : .clear)
                                        .overlay(Capsule().stroke(Palette.cardBorder, lineWidth: 1.5))
                                )
                        }
                    }
                }
                .padding(.top, 14)

                SectionLabel("STATE").padding(.top, 26)
                CardStack {
                    SettingRow(label: "Day", value: "\(model.progress?.dayNumber ?? 0)", divider: true)
                    SettingRow(label: "Cravings beaten",
                               value: "\(model.state.cravingsWon)", divider: true)
                    SettingRow(label: "Clock",
                               value: model.clock.isFrozen ? "frozen (seeded)" : "live",
                               divider: false)
                }

                Button("Reset everything") {
                    model.state = PersistedState()
                    model.draft = nil
                    model.onboardingStep = 0
                    model.debugMenuOpen = false
                }
                .font(.spaceGrotesk(14, weight: .bold))
                .foregroundStyle(Palette.ember)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().stroke(Palette.ember.opacity(0.4), lineWidth: 1.5))
                .padding(.top, 26)

                Spacer()
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 30)
        }
    }

    private func isCurrent(_ day: Int) -> Bool {
        model.progress?.dayNumber == day
    }

    /// Day N means N-1 midnights have passed, so back-date to the start of that
    /// day and keep the original time of day.
    private func travel(toDay day: Int) {
        guard var plan = model.state.plan else { return }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: model.clock.now)
        let target = calendar.date(byAdding: .day, value: -(day - 1), to: startOfToday) ?? startOfToday
        plan.quitDate = target.addingTimeInterval(8 * 3600)
        model.state.plan = plan
    }
}
