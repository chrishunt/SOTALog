import SwiftUI

/// A large monospaced callsign input field with optional times-worked badge.
/// Accepts an optional sanitizer closure for input filtering.
struct CallsignField: View {
    @Binding var text: String
    var timesWorked: Int = 0
    var workedToday: Int = 0
    var sanitizer: ((String) -> String)? = nil

    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 44

    private var badgeText: String? {
        if workedToday > 0 && timesWorked > 0 {
            return "\(workedToday) today · x\(timesWorked)"
        } else if workedToday > 0 {
            return "\(workedToday) today"
        } else if timesWorked > 0 {
            return "x\(timesWorked)"
        }
        return nil
    }

    var body: some View {
        HStack {
            TextField("CALLSIGN", text: $text)
                .font(.system(size: max(fontSize, 44), weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.6)
                .textContentType(.none)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                #if os(iOS)
                .keyboardType(.asciiCapable)
                #endif
                .onChange(of: text) { _, newValue in
                    text = sanitizer?(newValue) ?? newValue.sanitizedCallsign
                }

            if let badge = badgeText {
                Text(badge)
                    .font(.title3.bold())
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appOrange.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel(workedToday > 0 ? "Worked \(workedToday) times today, \(timesWorked) times total" : "Worked \(timesWorked) times before")
            }
        }
    }
}
