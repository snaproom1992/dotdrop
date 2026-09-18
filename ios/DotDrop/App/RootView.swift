import SwiftUI
import DotDropEngine

struct RootView: View {
    @State private var playing = false

    private let ink = Color(red: 0xF2 / 255, green: 0xF1 / 255, blue: 0xEE / 255)
    private let bg = Color(red: 0x2A / 255, green: 0x23 / 255, blue: 0x22 / 255)
    private let accent = Color(red: 0xD7 / 255, green: 0x14 / 255, blue: 0x1F / 255)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 28) {
                title
                Text("引っ張ってはなす")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ink.opacity(0.7))
                Text("Engine \(EngineInfo.version)")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.45))
                Button {
                    playing = true
                } label: {
                    Circle()
                        .fill(accent)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text("▶")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(ink)
                                .offset(x: 3)
                        )
                }
                .accessibilityLabel("はじめる")
            }
            .padding(32)
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
                .frame(width: 18, height: 18)
                .padding(.horizontal, 4)
            Text("T  DROP")
        }
        .font(.system(size: 44, weight: .heavy))
        .foregroundStyle(ink)
    }
}

#Preview {
    RootView()
}
