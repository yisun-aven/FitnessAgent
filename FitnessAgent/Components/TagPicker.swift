import SwiftUI

struct TagPicker: View {
    let tags: [String]
    @Binding var selection: String

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    selection = tag
                } label: {
                    HStack(spacing: 6) {
                        if selection == tag { Image(systemName: "checkmark.circle.fill") }
                        Text(tag.capitalized.replacingOccurrences(of: "_", with: " "))
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selection == tag ? AppTheme.accent.opacity(0.22) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selection == tag ? AppTheme.accent : Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
