import SwiftUI

/// The healing timeline. Passed milestones are filled, the next one carries a
/// progress bar and its scheduled notification date, the rest sit faint.
struct MilestonesScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            if let plan = model.plan, let progress = model.progress {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    ForEach(
                        Milestones.states(for: plan.product, hoursElapsed: progress.hoursElapsed),
                        id: \.milestone.id
                    ) { entry in
                        MilestoneRow(
                            milestone: entry.milestone,
                            state: entry.state,
                            scheduledDate: model.state.notifyMilestones
                                ? entry.milestone.date(from: plan.quitDate)
                                : nil
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack {
            Text("Your body, healing")
                .font(.spaceGrotesk(22, weight: .bold, relativeTo: .title))

            Spacer()

            Button {
                model.state.notifyMilestones.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text("alerts")
                        .font(.spaceGrotesk(11))
                        .foregroundStyle(Palette.textMuted)
                    TogglePip(isOn: model.state.notifyMilestones, width: 40, height: 24)
                }
            }
            .accessibilityLabel("Milestone alerts")
            .accessibilityValue(model.state.notifyMilestones ? "on" : "off")
        }
        .padding(.bottom, 14)
    }
}

struct MilestoneRow: View {
    let milestone: Milestone
    let state: Milestones.State
    let scheduledDate: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            stateDot
                .frame(width: 14, height: 14)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(milestone.title)
                        .font(.spaceGrotesk(15, weight: .bold))
                        .foregroundStyle(titleColour)
                    Spacer(minLength: 0)
                    Text(milestone.when)
                        .font(.spaceGrotesk(11.5))
                        .foregroundStyle(Palette.textFaint)
                }

                Text(milestone.body)
                    .font(.spaceGrotesk(12.5))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                if case .next(let fraction) = state {
                    ProgressRail(fraction: fraction)
                        .frame(height: 5)
                        .padding(.top, 9)

                    if let scheduledDate {
                        ScheduledChip(date: scheduledDate)
                            .padding(.top, 8)
                    }
                }
            }
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(milestone.title), \(milestone.when). \(statusWord). \(milestone.body)")
    }

    private var statusWord: String {
        switch state {
        case .passed: "Reached"
        case .next: "Next up"
        case .future: "Still ahead"
        }
    }

    @ViewBuilder
    private var stateDot: some View {
        switch state {
        case .passed:
            Circle().fill(Palette.accent)
        case .next:
            Circle()
                .strokeBorder(Palette.ember, lineWidth: 2)
                .shadow(color: Palette.ember.opacity(0.5), radius: 5)
        case .future:
            Circle().strokeBorder(Palette.textPrimary.opacity(0.2), lineWidth: 2)
        }
    }

    private var titleColour: Color {
        switch state {
        case .passed: Palette.textPrimary
        case .next: Palette.emberSoft
        case .future: Palette.textPrimary.opacity(0.45)
        }
    }
}

struct ProgressRail: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.textPrimary.opacity(0.1))
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: max(3, geo.size.width * fraction))
            }
        }
        .accessibilityHidden(true)
    }
}

struct ScheduledChip: View {
    let date: Date

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Palette.accent).frame(width: 5, height: 5)
            Text("notification scheduled · \(date.formatted(.dateTime.day().month(.abbreviated)))")
                .font(.spaceGrotesk(10.5))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Palette.accent.opacity(0.08))
                .overlay(Capsule().stroke(Palette.accent.opacity(0.2), lineWidth: 1))
        )
    }
}

/// The toggle used on Milestones and in Settings.
struct TogglePip: View {
    let isOn: Bool
    var width: CGFloat = 44
    var height: CGFloat = 26

    var body: some View {
        Capsule()
            .fill(isOn ? Palette.accent : Palette.textPrimary.opacity(0.15))
            .frame(width: width, height: height)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Palette.textBrightest)
                    .padding(2)
            }
            .animation(.snappy(duration: 0.18), value: isOn)
    }
}
