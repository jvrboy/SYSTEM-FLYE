import SwiftUI

// MARK: - Shared detail view components
// Centralised to avoid duplicate top-level type definitions across the
// detail view files (HeatmapGridView, NetworkTopologyView, NeuralLabDetailView,
// TechnicalIndicatorDetailView, etc.).

/// Compact stat row used throughout the detail views.
/// Signature: `StatCard(label: String, value: String)`.
struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Toggle row with title + subtitle + bound switch.
struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(SystemFlyeTheme.cyan)
        }
    }
}

/// Generic list item with primary text, secondary text, and an optional value.
struct ListItem: View {
    let title: String
    let subtitle: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SystemFlyeTheme.cyan)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }
}

/// Sectioned list header row used inside scroll views.
struct SectionItem: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            if let subtitle {
                Text(subtitle)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }
}

#if DEBUG
#Preview("StatCard") {
    StatCard(label: "RSI", value: "62.4")
        .preferredColorScheme(.dark)
        .padding()
}

#Preview("ToggleRow") {
    struct TogglePreview: View {
        @State private var on = true
        var body: some View {
            ToggleRow(title: "Enable alerts", subtitle: "Push alerts when thresholds are crossed", isOn: $on)
        }
    }
    return TogglePreview().preferredColorScheme(.dark).padding()
}
#endif
