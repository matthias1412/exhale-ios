import SwiftUI

struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var testSent = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if let plan = model.plan {
                        SectionLabel("YOUR QUIT PLAN").padding(.top, 24)
                        planCard(plan)

                        Button("Adjust my plan") {
                            model.settingsOpen = false
                            model.draft = plan
                            model.onboardingStep = 0
                            model.state.phase = .onboarding
                        }
                        .font(.spaceGrotesk(13))
                        .foregroundStyle(Palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(6)
                        .padding(.top, 4)
                    }

                    SectionLabel("NOTIFICATIONS").padding(.top, 22)
                    notificationCard

                    if let plan = model.plan, let progress = model.progress,
                       model.state.notifyMilestones {
                        let upcoming = Milestones.upcoming(
                            for: plan.product, hoursElapsed: progress.hoursElapsed
                        )
                        if !upcoming.isEmpty {
                            SectionLabel("COMING UP").padding(.top, 22)
                            upcomingCard(upcoming, quitDate: plan.quitDate)
                        }
                    }

                    testButton.padding(.top, 22)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack {
            Button {
                model.settingsOpen = false
            } label: {
                Text("← Back")
                    .font(.spaceGrotesk(14))
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer()
            Text("SETTINGS")
                .font(.spaceGrotesk(13, weight: .bold))
                .tracking(2.86)
                .foregroundStyle(Palette.accent)
        }
        .padding(.top, 8)
    }

    private func planCard(_ plan: QuitPlan) -> some View {
        CardStack {
            SettingRow(label: "Quitting", value: plan.config.displayName, divider: true)
            SettingRow(
                label: "Habit",
                value: "\(plan.amount) \(plan.config.unitNoun) \(plan.config.period == .day ? "a day" : "a week")",
                divider: true
            )
            SettingRow(
                label: "Unit price",
                value: plan.unitPrice.currencyString(plan.currencyCode),
                divider: false
            )
        }
    }

    private var notificationCard: some View {
        CardStack {
            ToggleRow(
                title: "Milestone alerts",
                subtitle: "The moment your body hits each healing milestone",
                isOn: model.state.notifyMilestones,
                divider: true
            ) { model.state.notifyMilestones.toggle() }

            ToggleRow(
                title: "Weekly bill",
                subtitle: "Sunday summary of money kept and units avoided",
                isOn: model.state.notifyWeeklyBill,
                divider: true
            ) { model.state.notifyWeeklyBill.toggle() }

            ToggleRow(
                title: "Morning check-in",
                subtitle: "A quiet nudge at 9:00 — one day at a time",
                isOn: model.state.notifyMorningCheckIn,
                divider: false
            ) { model.state.notifyMorningCheckIn.toggle() }
        }
    }

    private func upcomingCard(_ milestones: [Milestone], quitDate: Date) -> some View {
        CardStack {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                HStack(spacing: 10) {
                    Text(milestone.title)
                        .font(.spaceGrotesk(13.5, weight: .medium))
                    Spacer(minLength: 0)
                    Text(milestone.date(from: quitDate)
                        .formatted(.dateTime.day().month(.abbreviated)))
                        .font(.spaceGrotesk(12))
                        .foregroundStyle(Palette.accent)
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    if index < milestones.count - 1 {
                        Rectangle().fill(Palette.hairline).frame(height: 1)
                    }
                }
            }
        }
    }

    private var testButton: some View {
        Button {
            testSent = true
            Task { await NotificationScheduler.shared.sendTestNotification(state: model.state) }
        } label: {
            Text(testSent ? "Sent — check your lock screen" : "Send me a test notification")
                .font(.spaceGrotesk(14, weight: .bold))
                .foregroundStyle(Palette.accentSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule().stroke(Palette.accent.opacity(0.4), lineWidth: 1.5)
                )
        }
        .disabled(testSent)
    }
}

// MARK: - Small pieces

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.spaceGrotesk(11, weight: .medium))
            .tracking(1.98)
            .foregroundStyle(Palette.textFaint)
    }
}

struct CardStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Palette.textPrimary.opacity(0.12), lineWidth: 1)
            )
            .padding(.top, 10)
    }
}

struct SettingRow: View {
    let label: String
    let value: String
    let divider: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.spaceGrotesk(14))
                .foregroundStyle(Palette.textMuted)
            Spacer()
            Text(value)
                .font(.spaceGrotesk(14, weight: .bold))
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(Palette.hairline).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    let divider: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.spaceGrotesk(14, weight: .bold))
                Text(subtitle)
                    .font(.spaceGrotesk(11.5))
                    .foregroundStyle(Palette.textPrimary.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: toggle) { TogglePip(isOn: isOn) }
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(Palette.hairline).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { toggle() }
    }
}
