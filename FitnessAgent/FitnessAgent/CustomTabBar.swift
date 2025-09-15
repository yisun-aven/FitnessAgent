import SwiftUI

struct CustomTabBar: View {
    @Binding var selection: Int

    private let titles = ["Home", "Task", "Coach", "Crew", "Me"]
    private let iconNames = ["Home", "Tasks", "CoachEclip", "Friends", "Profile"]

    private let containerColor = Color(red: 0.17, green: 0.17, blue: 0.17)
    private let accent = Color(red: 0.59, green: 1.0, blue: 0.99)

    var body: some View {
        GeometryReader { geo in
            let containerWidth: CGFloat = 354
            let containerHeight: CGFloat = 54
            let bumpSize: CGFloat = 64
            let horizontalInset: CGFloat = 14 // keep content away from rounded edges
            let middleGap: CGFloat = bumpSize + 12 // more clearance so right side won't drift into bump

            ZStack(alignment: .bottom) {
                // Main rounded container
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: containerWidth, height: containerHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 50, style: .continuous)
                            .fill(containerColor)
                    )

                // Center bump
                Circle()
                    .fill(containerColor)
                    .frame(width: bumpSize + 24, height: bumpSize + 24)
                    // Lower the outer bump slightly so it hugs the bar
                    // .offset(y: -(containerHeight/2 - 2))
                    .offset(y: -(containerHeight/2) + 27)

                // Selected bump highlight for the center tab (Coach)
                // Cyan bump when Coach is selected; dark bump otherwise is drawn above
                Circle()
                    .fill(selection == 2 ? accent : containerColor)
                    .frame(width: bumpSize, height: bumpSize)
                    // Match the outer bump vertical position
                    .offset(y: -(containerHeight/2) + 15)
                    .overlay(
                        Circle().stroke(Color.clear, lineWidth: 0)
                    )
                    .contentShape(Circle())
                    .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = 2 } }

                // Items
                HStack(spacing: 0) {
                    // Left side centered within its half
                    HStack(spacing: 0) {
                        Spacer(minLength: 10)
                        tabButton(index: 0)
                        Spacer(minLength: 12)
                        tabButton(index: 1)
                        Spacer(minLength: 10)
                    }
                    .frame(maxWidth: .infinity)

                    // Gap for the bump in the middle
                    Spacer(minLength: middleGap)

                    // Right side centered within its half
                    HStack(spacing: 0) {
                        Spacer(minLength: 10)
                        tabButton(index: 3)
                        Spacer(minLength: 12)
                        tabButton(index: 4)
                        Spacer(minLength: 10)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: containerWidth - 24, height: containerHeight)
                .padding(.horizontal, horizontalInset)
            }
            .frame(maxWidth: .infinity, maxHeight: containerHeight + (bumpSize/2) + 12, alignment: .bottom)
        }
        .frame(height: 104) // provide space for the bump, closer to Figma
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Tab Button
    @ViewBuilder
    private func tabButton(index i: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selection = i
            }
        } label: {
            HStack(spacing: 6) {
                Image(iconNames[i])
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(i == selection ? .black : .white.opacity(0.8))
                if i == selection && i != 2 {
                    Text(titles[i])
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, i == selection && i != 2 ? 10 : 0)
            .frame(height: 40, alignment: .leading)
            .frame(minWidth: i == selection && i != 2 ? 76 : 44, alignment: .leading)
            .background(
                Group {
                    if i == selection && i != 2 {
                        RoundedRectangle(cornerRadius: 20, style: .continuous).fill(accent)
                    } else {
                        Color.clear
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(height: 54, alignment: .center) // center within the bar height
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selection)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StatefulPreviewWrapper(0) { selection in
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack { Spacer() }
        }
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selection: selection)
        }
    }
}

// Helper for binding in preview
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content
    init(_ initialValue: Value, content: @escaping (Binding<Value>) -> Content) {
        _value = State(wrappedValue: initialValue)
        self.content = content
    }
    var body: some View { content($value) }
}
