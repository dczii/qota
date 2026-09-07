import SwiftUI

struct UsageBar: View {
    var percent: Double
    var tint: Color
    var warnAt: Double
    var criticalAt: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(100, max(0, percent)) / 100
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(barColor)
                    .frame(width: max(6, proxy.size.width * clamped))
            }
        }
        .frame(height: 7)
        .accessibilityValue("\(Int(percent.rounded())) percent used")
    }

    private var barColor: Color {
        if percent >= criticalAt { return .red }
        if percent >= warnAt { return .orange }
        return tint
    }
}
