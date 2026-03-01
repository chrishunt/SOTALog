import SwiftUI

/// A large monospaced callsign input field with optional times-worked badge.
/// Accepts an optional sanitizer closure for input filtering.
struct CallsignField: View {
    @Binding var text: String
    var timesWorked: Int = 0
    var sanitizer: ((String) -> String)? = nil

    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 44

    var body: some View {
        HStack {
            TextField("CALLSIGN", text: $text)
                .font(.system(size: max(fontSize, 44), weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.6)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                #if os(iOS)
                .keyboardType(.asciiCapable)
                #endif
                .onChange(of: text) { _, newValue in
                    text = sanitizer?(newValue) ?? newValue.sanitizedCallsign
                }

            if timesWorked > 0 {
                Text("x\(timesWorked)")
                    .font(.title3.bold())
                    .foregroundStyle(Color.appOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appOrange.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel("Worked \(timesWorked) times before")
            }
        }
    }
}
