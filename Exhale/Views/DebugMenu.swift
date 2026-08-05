import SwiftUI

/// Reachable from Settings, or by five taps on the wordmark.
///
/// Time travel was already here — it is the only way to see day 1,825 without
/// waiting five years. What it could not do was replay anything: the spiral
/// arrival happens once per session by design, and a celebration only appears
/// when a milestone is genuinely crossed, so on a real device both were
/// effectively unwatchable. Every animation in the app can be triggered from
/// here now, at any day count, which is the only way to judge how they read
/// on hardware rather than in a simulator capture.
struct DebugMenu: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingReset = false

    private static let presets: [(label: String, day: Int)] = [
        ("Day 1", 1), ("Day 3", 3), ("Week 1", 7), ("Month 1", 30),
        ("90 days", 90), ("6 months", 180), ("1 year", 365),
        ("2 years", 730), ("5 years", 1825)
    ]

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    SectionLabel("TIME TRAVEL").padding(.top, 24)
                    Text("Moves the quit date so the streak reads as chosen. Everything else is derived, so the whole app follows.")
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    FlowLayout(spacing: 8) {
                        ForEach(Self.presets, id: \.day) { preset in
                            chip(preset.label, isOn: isCurrent(preset.day)) {
                                travel(toDay: preset.day)
                            }
                        }
                    }
                    .padding(.top, 14)

                    dayStepper.padding(.top, 14)

                    SectionLabel("ANIMATIONS").padding(.top, 26)
                    Text("The spiral arrives once per session, so switching tabs won't show it again. This forces it.")
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    wideButton("Replay the spiral arrival", tint: Palette.accent) {
                        model.hasRevealedSpiral = false
                        model.tab = .today
                        model.debugMenuOpen = false
                    }
                    .padding(.top, 12)

                    SectionLabel("CELEBRATIONS").padding(.top, 26)
                    Text("Jumps to the day the milestone lands on, plays its burst, then lets the spiral arrive behind it — the full sequence, in order.")
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    milestoneList.padding(.top, 10)

                    SectionLabel("STATE").padding(.top, 26)
                    CardStack {
                        SettingRow(label: "Day", value: "\(model.progress?.dayNumber ?? 0)", divider: true)
                        SettingRow(label: "Cravings beaten",
                                   value: "\(model.state.cravingsWon)", divider: true)
                        SettingRow(label: "Clock",
                                   value: model.clock.isFrozen ? "frozen (seeded)" : "live",
                                   divider: false)
                    }

                    SectionLabel("START OVER").padding(.top, 26)
                    Text("Clears the plan and history on this device and in iCloud, then runs onboarding from the top.")
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)

                    wideButton("Reset and run onboarding", tint: Palette.ember) {
                        confirmingReset = true
                    }
                    .padding(.top, 12)
                    .confirmationDialog("Reset everything?",
                                        isPresented: $confirmingReset,
                                        titleVisibility: .visible) {
                        Button("Reset and start over", role: .destructive) {
                            // The old version here rebuilt PersistedState by hand
                            // and never touched the iCloud mirror, so the next
                            // launch pulled the old plan straight back down and
                            // the reset looked like it had done nothing.
                            model.resetEverything()
                            model.debugMenuOpen = false
                        }
                        Button("Keep my streak", role: .cancel) {}
                    } message: {
                        Text("This cannot be undone.")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
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
    }

    /// The presets cover the shape of the bloom; this covers everything
    /// between them, which is where the awkward day counts live.
    private var dayStepper: some View {
        HStack(spacing: 14) {
            stepButton("−") { travel(toDay: max(1, currentDay - 1)) }
            VStack(spacing: 1) {
                Text("\(currentDay)")
                    .font(.spaceGrotesk(24, weight: .bold))
                    .monospacedDigit()
                Text("DAY").font(.spaceGrotesk(9, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(Palette.textFaint)
            }
            .frame(minWidth: 66)
            stepButton("+") { travel(toDay: currentDay + 1) }

            Spacer()

            Text(isMilestoneDay(currentDay) ? "milestone day" : " ")
                .font(.spaceGrotesk(11, weight: .medium))
                .foregroundStyle(Palette.accent)
        }
    }

    private var milestoneList: some View {
        CardStack {
            let all = Array(Milestones.forProduct(model.state.plan?.product ?? .cigarettes).enumerated())
            ForEach(all, id: \.element.id) { index, milestone in
                Button {
                    play(milestone)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(milestone.colour)
                            .frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(milestone.title)
                                .font(.spaceGrotesk(13.5, weight: .medium))
                                .foregroundStyle(Palette.textPrimary)
                            Text("\(milestone.when) · day \(day(of: milestone))")
                                .font(.spaceGrotesk(11))
                                .foregroundStyle(Palette.textFaint)
                        }
                        Spacer(minLength: 0)
                        Text("Play")
                            .font(.spaceGrotesk(12, weight: .bold))
                            .foregroundStyle(Palette.accent)
                    }
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .overlay(alignment: .bottom) {
                    if index < all.count - 1 {
                        Rectangle().fill(Palette.hairline).frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    private func chip(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.spaceGrotesk(13, weight: .bold))
                .foregroundStyle(isOn ? Palette.onAccent : Palette.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isOn ? Palette.accent : .clear)
                        .overlay(Capsule().stroke(Palette.cardBorder, lineWidth: 1.5))
                )
        }
    }

    private func stepButton(_ glyph: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.spaceGrotesk(19))
                .foregroundStyle(Palette.accent)
                .frame(width: 42, height: 42)
                .overlay(Circle().stroke(Palette.stepperBorder, lineWidth: 1.5))
        }
    }

    private func wideButton(_ title: String, tint: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.spaceGrotesk(14, weight: .bold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().stroke(tint.opacity(0.4), lineWidth: 1.5))
        }
    }

    // MARK: - Actions

    private var currentDay: Int { model.progress?.dayNumber ?? 1 }
    private func isCurrent(_ day: Int) -> Bool { currentDay == day }
    private func isMilestoneDay(_ day: Int) -> Bool { model.milestoneDays.contains(day) }

    private func day(of milestone: Milestone) -> Int {
        Int((milestone.hours / 24).rounded(.down)) + 1
    }

    /// Travels to the milestone's day and queues its celebration, with the
    /// spiral reset so the burst hands off to the arrival exactly as it would
    /// on the morning you actually crossed it.
    private func play(_ milestone: Milestone) {
        travel(toDay: day(of: milestone))
        model.hasRevealedSpiral = false
        model.tab = .today
        model.pendingCelebration = milestone
        model.debugMenuOpen = false
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
