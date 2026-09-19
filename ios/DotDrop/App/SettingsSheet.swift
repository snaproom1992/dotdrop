import SwiftUI

/// 設定のしるし。**丸だけで作る**（形は丸と四角と三角だけ、というルール）。
/// 歯車は使えないので、3本のつまみを「点の列」と「効いている点」で表した。
/// 効いている点だけ赤いのは、当たった釘・STAGE の進み具合と同じ扱い
struct DotSettingsIcon: View {
    var active: Color = DD.red
    var idle: Color = DD.paper.opacity(0.3)
    /// 各行で赤くする点の位置。ばらけていないと「つまみ」に見えない
    private let marks = [1, 3, 0]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(marks.indices, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { col in
                        Circle()
                            .fill(col == marks[row] ? active : idle)
                            .frame(width: 3.5, height: 3.5)
                    }
                }
            }
        }
    }
}

/// 音・振動・演出の設定。下から出る板。
///
/// **リセットの板には入れないこと。**あちらは「やめるかどうか」を聞く場で、
/// 設定とは用事が違う。キャンセルの下に別の操作が付くと、板の終わりも分からなくなる
struct SettingsSheet: View {
    var safeBottom: CGFloat
    var onClose: () -> Void

    @State private var shown = false
    @State private var drag: CGFloat = 0
    /// 6pt 以上引いたら、指を離してもボタンを押したことにしない
    @State private var moved = false
    @State private var closing = false
    @AppStorage("dotdrop-sound") private var soundEnabled = true
    @AppStorage("dotdrop-haptics") private var hapticsEnabled = true
    @AppStorage("dotdrop-calm-effects") private var calmEffects = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let slideIn = Animation.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.24)

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x1C1716)
                .opacity(shown ? 0.74 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            card
                .offset(y: shown ? drag : 1_200)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            drag = max(0, v.translation.height)
                            if drag > 6 { moved = true }
                        }
                        .onEnded { _ in
                            let far = drag > 70
                            withAnimation(reduceMotion ? nil : Self.slideIn) { drag = 0 }
                            if far { close() }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { moved = false }
                        }
                )
        }
        .onAppear { withAnimation(reduceMotion ? nil : Self.slideIn) { shown = true } }
        .onChange(of: soundEnabled) { _, enabled in
            if !enabled { GameAudio.shared.suspend() }
        }
        .onChange(of: hapticsEnabled) { _, enabled in
            if !enabled { GameHaptics.cancel() }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            // つまみ。下へ引けることを形で示す
            Capsule()
                .fill(DD.paper.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)

            Text("音・振動・演出")
                .font(DD.bold(17))
                .foregroundStyle(DD.paper)
                .padding(.top, 14)

            VStack(spacing: 0) {
                row("サウンド", $soundEnabled)
                divider
                row("振動", $hapticsEnabled)
                divider
                row("点滅・揺れを抑える", $calmEffects)
            }
            .padding(.top, 18)

            Button { if !moved { close() } } label: {
                Text("閉じる")
                    .font(DD.bold(14))
                    .foregroundStyle(DD.paper.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        // 下は画面の端まで。ホームバーのぶんだけ中身を上げる
        .padding(.bottom, safeBottom + 26)
        .background(DD.brown)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
    }

    private func row(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            Text(title)
                .font(DD.regular(15))
                .foregroundStyle(DD.paper)
        }
        .tint(DD.mustard)
        .padding(.vertical, 11)
    }

    private var divider: some View {
        Rectangle().fill(DD.paper.opacity(0.12)).frame(height: 1)
    }

    private func close() {
        guard !closing else { return }
        closing = true
        withAnimation(reduceMotion ? nil : Self.slideIn) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.24)) {
            onClose()
        }
    }
}
