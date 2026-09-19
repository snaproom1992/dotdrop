import SwiftUI

/// Liquid Glass の下地。タイトルの2つのボタン（きろく・設定）で使う。
///
/// 色は世界観に寄せて**マスタードの薄い色味**（22%）。赤は「はじめる」が使っている
/// ので右上の小さなものに使うと主役とぶつかる。白（クリーム）は玉の色なので単色では
/// 使わない。残るのがマスタード。
///
/// **Liquid Glass は iOS 26 から。**古い Xcode ではそもそも API が無いので
/// `compiler(>=6.2)` でも切り分ける。それ以前は同じ形に薄い地と細い枠を敷く
extension View {
    @ViewBuilder
    func glassChip<S: Shape>(_ shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(DD.mustard.opacity(0.22)).interactive(), in: shape)
        } else {
            self.background(DD.mustard.opacity(0.14), in: shape)
                .overlay(shape.stroke(DD.paper.opacity(0.18), lineWidth: 1))
        }
        #else
        self.background(DD.mustard.opacity(0.14), in: shape)
            .overlay(shape.stroke(DD.paper.opacity(0.18), lineWidth: 1))
        #endif
    }
}

/// 設定の入口。iOS の歯車。
/// **「形は丸と四角と三角だけ」の例外。**自作の印は何を指すか伝わらなかった
struct SettingsButton: View {
    var body: some View {
        Image(systemName: "gearshape")
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(DD.paper.opacity(0.75))
            .frame(width: 44, height: 44)
            .glassChip(Circle())
    }
}

/// 記録の入口。**こちらは文字にする。**トロフィーなどの印は意味が決まらない
struct RecordsButton: View {
    var body: some View {
        Text("きろく")
            .font(DD.bold(13))
            .foregroundStyle(DD.paper.opacity(0.75))
            .padding(.horizontal, 16)
            .frame(height: 44)
            .glassChip(Capsule())
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
