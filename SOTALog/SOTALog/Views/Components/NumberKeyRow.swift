#if os(iOS)
import SwiftUI

struct NumberKeyRow: View {
    let onKey: (String) -> Void

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "/"]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { key in
                Button {
                    onKey(key)
                } label: {
                    Text(key)
                        .font(.appNumberKey)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.appSurfaceRaised, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 3)
    }
}
#endif
