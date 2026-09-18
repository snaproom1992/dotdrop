import SwiftUI
import DotDropEngine

/// フェーズ0のプレースホルダ。盤面・操作はまだない。
struct RootView: View {
    private let ink = Color(red: 0xF2 / 255, green: 0xF1 / 255, blue: 0xEE / 255)
    private let bg = Color(red: 0x2A / 255, green: 0x23 / 255, blue: 0x22 / 255)
    private let accent = Color(red: 0xD7 / 255, green: 0x14 / 255, blue: 0x1F / 255)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 28) {
                title
                Text("iOS ネイティブ移植（準備中）")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ink.opacity(0.7))
                Text("Engine \(EngineInfo.version) · 論理幅 \(Int(EngineInfo.logicalWidth))")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.45))
                Circle()
                    .fill(accent)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Text("▶")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(ink)
                            .offset(x: 3)
                    )
                    .accessibilityLabel("はじめる（準備中）")
            }
            .padding(32)
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
