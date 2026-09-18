import SwiftUI
import DotDropEngine

struct RootView: View {
    @State private var playing = false

    private let ink = Color(hex: 0xF2F1EE)
    private let bg = Color(hex: 0x2A2322)
    private let accent = Color(hex: 0xD7141F)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 36) {
                Spacer()
                title
                Spacer()
                Button {
                    playing = true
                } label: {
                    Text("はじめる")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(ink)
                        .frame(width: 200, height: 56)
                        .background(accent)
                        .clipShape(Capsule())
                }
                .padding(.bottom, 48)
            }
        }
        .fullScreenCover(isPresented: $playing) {
            PlayView()
        }
    }

    private var title: some View {
        HStack(spacing: 0) {
            Text("D")
            Circle()
                .fill(ink)
                .frame(width: 22, height: 22)
                .padding(.horizontal, 5)
            Text("T")
            Text("  DROP")
        }
        .font(.system(size: 52, weight: .heavy))
        .foregroundStyle(ink)
    }
}

#Preview {
    RootView()
}
