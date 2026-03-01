import SwiftUI

/// Quick-pick RST selector. Defaults to 599. Common CW RST values available as tappable buttons.
struct RSTField: View {
    @Binding var value: String
    @State private var showPicker = false

    private static let commonValues = ["599", "579", "559", "539", "519", "339"]

    var body: some View {
        Button {
            showPicker.toggle()
        } label: {
            Text(value)
                .font(.title3.monospacedDigit().bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker) {
            VStack(spacing: 0) {
                ForEach(Self.commonValues, id: \.self) { rst in
                    Button {
                        value = rst
                        showPicker = false
                    } label: {
                        Text(rst)
                            .font(.title2.monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(value == rst ? Color.accentColor.opacity(0.15) : .clear)
                    }
                    .buttonStyle(.plain)

                    if rst != Self.commonValues.last {
                        Divider()
                    }
                }
            }
            .frame(width: 120)
            .presentationCompactAdaptation(.popover)
        }
    }
}
