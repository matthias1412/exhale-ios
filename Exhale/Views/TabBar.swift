import SwiftUI

/// The floating tab bar.
///
/// iOS 26's Liquid Glass where it exists, a material blur below that. It is a
/// capsule that floats over the content rather than a bar welded to the bottom
/// edge, which is the change that actually makes it read as current — the old
/// version was a flat strip with a hairline above it.
///
/// Guarded on both the OS version *and* the symbol's presence at runtime.
/// `UIGlassEffect` shipped broken in early iOS 26 betas and crashed on init;
/// Expo's wrapper does the same double check for the same reason, and a quit
/// app crashing on launch would be unforgivable for a cosmetic effect.
struct TabBar: View {
    @Environment(AppModel.self) private var model
    @Namespace private var selectionNamespace

    var body: some View {
        if let progress = model.progress, !progress.hasStarted {
            EmptyView()
        } else {
            bar
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
        }
    }

    private var bar: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    // The selection glides between tabs rather than cutting.
                    withAnimation(.snappy(duration: 0.28, extraBounce: 0.12)) {
                        model.tab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.spaceGrotesk(13, weight: .bold))
                        .foregroundStyle(model.tab == tab ? Palette.onAccent : Palette.textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            if model.tab == tab {
                                Capsule()
                                    .fill(Palette.accent)
                                    .matchedGeometryEffect(id: "tab", in: selectionNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.tab == tab ? [.isSelected] : [])
            }
        }
        .padding(5)
        .background(glass)
    }

    @ViewBuilder
    private var glass: some View {
        if #available(iOS 26.0, *), LiquidGlass.isAvailable {
            Capsule().fill(.clear).glassEffect(.regular, in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().stroke(Palette.textPrimary.opacity(0.10), lineWidth: 1)
                )
        }
    }
}

/// `UIGlassEffect` was present but non-functional in early iOS 26 betas, where
/// initialising it crashed. Checking the class responds before relying on the
/// SwiftUI modifier costs nothing and cannot crash.
enum LiquidGlass {
    static let isAvailable: Bool = {
        guard #available(iOS 26.0, *) else { return false }
        guard let glass = NSClassFromString("UIGlassEffect") as? NSObject.Type else {
            return false
        }
        return glass.responds(to: Selector(("effectWithStyle:")))
    }()
}
