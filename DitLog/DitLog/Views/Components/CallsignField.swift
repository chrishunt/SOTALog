import SwiftUI

/// A 44pt monospaced callsign input field.
struct CallsignField: View {
    @Binding var text: String
    var timesWorked: Int = 0

    var body: some View {
        HStack {
            TextField("CALLSIGN", text: $text)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: text) { _, newValue in
                    text = newValue.sanitizedCallsign
                }

            if timesWorked > 0 {
                Text("x\(timesWorked)")
                    .font(.title3.bold())
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
