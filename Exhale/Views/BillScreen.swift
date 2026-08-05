import SwiftUI

/// The Running Bill — a printed receipt that has wandered into a dark app.
///
/// The typographic clash is the point: cream paper, Archivo Black, dotted
/// leaders and a torn bottom edge, sitting inside an otherwise sea-glass-and-
/// ink interface. It should feel like an object, not a screen.
struct BillScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            if let plan = model.plan {
                LiveProgress(plan: plan, clock: model.clock) { progress in
                VStack(spacing: 0) {
                    receipt(plan: plan, progress: progress)
                    TornEdge()
                        .fill(Palette.paper)
                        .frame(height: 14)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 14)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func receipt(plan: QuitPlan, progress: QuitProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            moneyBlock(plan: plan, progress: progress)
            rows(plan: plan, progress: progress)
            TallyBlock(plan: plan, containers: progress.containersAvoided)
                .padding(.top, 20)
            footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 26)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 6, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 6
            )
            .fill(Palette.paper)
        )
        .foregroundStyle(Palette.ink)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("THE RUNNING BILL")
                    .font(.archivoBlack(14))
                    .tracking(0.84)
                Spacer()
                Text("what it owed you")
                    .font(.archivo(10.5))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
            .padding(.bottom, 10)

            Rectangle().fill(Palette.ink).frame(height: 2.5)
        }
    }

    private func moneyBlock(plan: QuitPlan, progress: QuitProgress) -> some View {
        let money = progress.moneyKept.moneyString(plan.currencyCode)
        return VStack(alignment: .leading, spacing: 0) {
            Text("KEPT IN YOUR POCKET")
                .font(.archivo(11, weight: .semibold))
                .tracking(1.98)
                .foregroundStyle(Palette.paperAccent)
                .padding(.top, 22)
                .padding(.bottom, 4)

            // Shrinks as the figure grows so it never wraps or truncates.
            Text(money)
                .font(.archivoBlack(moneySize(for: money)))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("and counting — day \(progress.dayNumber), since \(sinceDate(plan))")
                .font(.archivo(12))
                .foregroundStyle(Palette.ink.opacity(0.6))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(money) kept in your pocket, day \(progress.dayNumber)")
    }

    private func moneySize(for text: String) -> CGFloat {
        switch text.count {
        case ...8: 54
        case 9...11: 46
        default: 38
        }
    }

    private func sinceDate(_ plan: QuitPlan) -> String {
        let progress = QuitProgress(plan: plan, now: model.clock.now)
        return progress.dayNumber > 300
            ? plan.quitDate.formatted(.dateTime.day().month(.abbreviated).year())
            : plan.quitDate.formatted(.dateTime.day().month(.abbreviated))
    }

    private func rows(plan: QuitPlan, progress: QuitProgress) -> some View {
        VStack(spacing: 0) {
            ForEach(billRows(plan: plan, progress: progress), id: \.label) { row in
                LeaderRow(label: row.label, value: row.value)
            }
        }
        .padding(.top, 20)
    }

    private func billRows(plan: QuitPlan, progress: QuitProgress) -> [(label: String, value: String)] {
        let config = plan.config
        var rows: [(String, String)] = [
            (config.unitNoun.capitalisedFirst + " avoided",
             progress.unitsAvoided.formatted(.number)),
            (config.containerNoun.capitalisedFirst + " not bought",
             progress.containersAvoided.formatted(.number))
        ]
        if plan.product == .cigarettes {
            rows.append(("Hours of life won back", progress.hoursReclaimed.formatted(.number)))
        }
        rows.append(("Cravings beaten in-app", model.state.cravingsWon.formatted(.number)))
        return rows
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.ink).frame(height: 2.5).padding(.top, 22)

            HStack {
                Text("Paid to: ")
                    .font(.archivo(11.5))
                    .foregroundStyle(Palette.ink.opacity(0.6))
                + Text("yourself")
                    .font(.archivo(11.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)

                Spacer()

                Text("EXHALE")
                    .font(.archivoBlack(11))
                    .tracking(1.1)
                    .foregroundStyle(Palette.paperAccent)
            }
            .padding(.top, 12)
        }
    }
}

/// A label, a dotted leader that stretches, and a value — the receipt idiom.
struct LeaderRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.archivo(13, weight: .medium))
            DottedLeader()
                .frame(height: 2)
                .frame(maxWidth: .infinity)
                .offset(y: -3)
            Text(value)
                .font(.archivoBlack(16))
                .monospacedDigit()
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.ink.opacity(0.18)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct DottedLeader: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
            }
            .stroke(
                Palette.ink.opacity(0.35),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.1, 4])
            )
        }
    }
}

/// Crossed-out containers. Past 40 the glyphs would run off the page, so each
/// one starts meaning ten and carries a badge saying so.
struct TallyBlock: View {
    let plan: QuitPlan
    let containers: Int

    private var collapsed: Bool { containers > 40 }
    private var glyphCount: Int {
        collapsed ? min(40, containers / 10) : containers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(plan.config.tallyLabel)
                .font(.archivo(10.5))
                .tracking(1.47)
                .foregroundStyle(Palette.ink.opacity(0.5))

            FlowLayout(spacing: 7) {
                ForEach(0..<glyphCount, id: \.self) { _ in
                    TallyGlyphView(
                        glyph: plan.config.tallyGlyph,
                        badge: collapsed ? "10" : nil
                    )
                }
            }

            if collapsed {
                Text("each mark = 10 \(plan.config.containerNoun) · \(containers.formatted(.number)) total")
                    .font(.archivo(10.5))
                    .foregroundStyle(Palette.ink.opacity(0.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(plan.config.containers(containers)) not bought"
        )
    }
}

struct TallyGlyphView: View {
    let glyph: TallyGlyph
    let badge: String?

    private var width: CGFloat { glyph.width + (badge == nil ? 0 : 4) }
    private var height: CGFloat { glyph.height + (badge == nil ? 0 : 4) }

    var body: some View {
        ZStack {
            shape.stroke(Palette.ink, lineWidth: 1.5)
            // The strike-through, bottom-left to top-right.
            Path { path in
                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: width, y: 0))
            }
            .stroke(Palette.paperAccent, lineWidth: max(1.5, height * 0.12))
            .clipShape(shape)

            if let badge {
                Text(badge)
                    .font(.archivoBlack(9))
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .background(Palette.paper)
            }
        }
        .frame(width: width, height: height)
    }

    private var shape: AnyShape {
        if let radius = glyph.cornerRadius {
            AnyShape(RoundedRectangle(cornerRadius: radius))
        } else {
            AnyShape(Circle())
        }
    }
}

/// The torn bottom edge of the receipt.
struct TornEdge: Shape {
    var toothWidth: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        var x = rect.minX
        var down = true
        while x < rect.maxX {
            let next = min(x + toothWidth, rect.maxX)
            path.addLine(to: CGPoint(x: next, y: down ? rect.maxY : rect.minY))
            x = next
            down.toggle()
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Wraps the tally glyphs onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize,
        subviews: Subviews, cache: inout ()
    ) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension String {
    var capitalisedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
