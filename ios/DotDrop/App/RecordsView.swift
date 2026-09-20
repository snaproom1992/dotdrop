import SwiftUI
import UIKit

/// ランキングと「これまでの記録」。結果画面とタイトルの「きろく」で同じものを使う。
///
/// **2か所で作り分けないこと。**片方だけ直して見た目がずれる
struct RecordsSections: View {
    var entries: [DDStore.RankEntry]
    var records: [String: Int]
    /// マスタードで塗る回（結果画面では今回の回。タイトルでは nil）
    var highlight: DDStore.RankEntry?
    /// 「更新」の札を出す項目
    var newKeys: Set<String> = []
    var limit: Int = 5

    /// この端末の記録か、世界ランキングか
    enum Scope { case local, world }
    @State private var scope: Scope = .local

    var body: some View {
        VStack(spacing: 0) {
            section("ランキング") {
                scopeSwitch
                if scope == .local { ranking } else { worldRanking }
            }
            section("これまでの記録") { recordGrid }
        }
        .onAppear { Self.styleSegments() }
    }

    private func section<C: View>(
        _ title: LocalizedStringKey, @ViewBuilder content: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DD.bold(12))
                .tracking(0.48)
                .foregroundStyle(DD.paper.opacity(0.6))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 36)
    }

    // MARK: - あなた / 世界ランキング の切り替え

    /// iOS 標準の切り替え（`Picker` の segmented）。指で滑らせて動かせて、
    /// 選んだところが滑らかに動く。**見出しの下に1行まるごと使う**
    private var scopeSwitch: some View {
        Picker("ランキングの範囲", selection: $scope) {
            Text("あなた").tag(Scope.local)
            Text("世界ランキング").tag(Scope.world)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.top, 2)
        .padding(.bottom, 8)
        .onChange(of: scope) { _, value in
            if value == .world { GameCenter.shared.load() }
        }
    }

    /// 標準の切り替えは明るい灰色で、こげ茶の板の上では浮いてしまう。
    /// 選んだところを赤、字をクリームにして、色の決まりに合わせる。
    /// アプリの中にこれ1つしかないので、まとめて指定してよい
    private static func styleSegments() {
        let bar = UISegmentedControl.appearance()
        bar.selectedSegmentTintColor = UIColor(DD.red)
        bar.backgroundColor = UIColor(DD.paper.opacity(0.10))
        let font = UIFont(name: "HelveticaNeue-Bold", size: 13)
            ?? .systemFont(ofSize: 13, weight: .bold)
        bar.setTitleTextAttributes(
            [.foregroundColor: UIColor(DD.paper.opacity(0.6)), .font: font], for: .normal)
        bar.setTitleTextAttributes(
            [.foregroundColor: UIColor(DD.paper), .font: font], for: .selected)
    }

    // MARK: - 世界ランキング

    private var worldRanking: some View {
        VStack(spacing: 0) {
            if !GameCenter.shared.signedIn {
                note("Game Center にサインインすると、世界のスコアが見られます")
            } else {
                switch GameCenter.shared.state {
                case .loading, .idle: note("読み込んでいます")
                case .failed: note("いまは読み込めません")
                case .ready:
                    if GameCenter.shared.entries.isEmpty {
                        note("まだ誰も載っていません")
                    } else {
                        ForEach(GameCenter.shared.entries.prefix(limit)) { e in worldRow(e) }
                        // 上位に入っていなくても、自分の順位は見せる
                        if let me = GameCenter.shared.myEntry, !GameCenter.shared.entries.prefix(limit).contains(me) {
                            worldRow(me)
                        }
                    }
                }
            }
        }
    }

    private func worldRow(_ e: GameCenter.Entry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "\(e.rank)")
                .font(DD.bold(14))
                .opacity(0.7)
                .frame(width: 28, alignment: .leading)
            Text(verbatim: "\(e.score)")
                .font(DD.bold(20))
                .kerning(-0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: e.name)
                .font(DD.regular(11))
                .opacity(0.7)
                .lineLimit(1)
        }
        .foregroundStyle(e.isMe ? DD.ink : DD.paper)
        .padding(.vertical, 7)
        .padding(.horizontal, e.isMe ? 6 : 0)
        .background(e.isMe ? DD.mustard : .clear)
        .clipShape(RoundedRectangle(cornerRadius: e.isMe ? 4 : 0))
        .overlay(alignment: .top) {
            if !e.isMe { Rectangle().fill(DD.paper.opacity(0.14)).frame(height: 1) }
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(DD.regular(13))
            .foregroundStyle(DD.paper.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
    }

    private var ranking: some View {
        VStack(spacing: 0) {
            if entries.isEmpty {
                Text("まだ記録がありません")
                    .font(DD.regular(13))
                    .foregroundStyle(DD.paper.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 7)
            } else {
                ForEach(Array(entries.prefix(limit).enumerated()), id: \.offset) { i, r in
                    let me = highlight != nil && r == highlight
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "\(i + 1)")
                            .font(DD.bold(14))
                            .opacity(0.7)
                            .frame(width: 28, alignment: .leading)
                        Text(verbatim: "\(r.score)")
                            .font(DD.bold(20))
                            .kerning(-0.6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("ステージ\(r.stage)・\(month(r.date))/\(day(r.date))")
                            .font(DD.regular(11))
                            .opacity(0.7)
                    }
                    .foregroundStyle(me ? DD.ink : DD.paper)
                    .padding(.vertical, 7)
                    .padding(.horizontal, me ? 6 : 0)
                    .background(me ? DD.mustard : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: me ? 4 : 0))
                    .overlay(alignment: .top) {
                        if !me { Rectangle().fill(DD.paper.opacity(0.14)).frame(height: 1) }
                    }
                }
            }
        }
    }

    private var recordGrid: some View {
        let items = DDStore.recordLabels.filter { (records[$0.key] ?? 0) > 0 }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.key) { item in
                let isNew = newKeys.contains(item.key)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "\(records[item.key] ?? 0)")
                        .font(DD.bold(22))
                        .kerning(-0.66)
                        .foregroundStyle(DD.paper)
                    Text(item.label)
                        .font(DD.regular(11))
                        .foregroundStyle(DD.paper.opacity(0.65))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isNew ? DD.mustard.opacity(0.18) : DD.paper.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topTrailing) {
                    if isNew {
                        Text("更新")
                            .font(DD.bold(10))
                            .foregroundStyle(DD.ink)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(DD.mustard)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .padding(8)
                    }
                }
            }
        }
    }

    private func month(_ d: Date) -> Int { Calendar.current.component(.month, from: d) }
    private func day(_ d: Date) -> Int { Calendar.current.component(.day, from: d) }
}

/// タイトルから開く「きろく」。下から出る板。
///
/// **ベストスコアを主役にする。**ランキングの1位を大きく出して、結果画面と同じように
/// 0から回す。順位の並びや細かい記録は、そのあとに続ける
struct RecordsSheet: View {
    var safeBottom: CGFloat
    var maxHeight: CGFloat
    var onClose: () -> Void

    @State private var shown = false
    @State private var drag: CGFloat = 0
    @State private var moved = false
    @State private var closing = false
    @State private var entries: [DDStore.RankEntry] = []
    @State private var records: [String: Int] = [:]
    @State private var displayedBest = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let slideIn = Animation.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.24)
    private var best: Int { max(entries.first?.score ?? 0, records["gameScore"] ?? 0) }

    /// 板の中で使える幅（左右24）。リールの1枠は .57em
    private var bestSize: Double {
        let digits = Double(max(1, String(max(0, best)).count))
        return min(80, (320 - 48 - 4) / (digits * 0.57))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0x1C1716)
                .opacity(shown ? 0.74 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }
            card.offset(y: shown ? drag : 1_200)
        }
        .onAppear {
            entries = DDStore.ranking()
            records = DDStore.records()
            withAnimation(reduceMotion ? nil : Self.slideIn) { shown = true }
        }
        .task {
            // 結果画面と同じ回し方。0から上がって、リールで止まる
            let target = max(entries.first?.score ?? 0, DDStore.records()["gameScore"] ?? 0)
            let duration = reduceMotion ? 0 : min(1.2, 0.3 + Double(target) * 0.0015)
            let began = Date()
            while !Task.isCancelled {
                let p = duration == 0 ? 1 : min(1, Date().timeIntervalSince(began) / duration)
                displayedBest = Int((Double(target) * (1 - pow(1 - p, 3))).rounded())
                if p >= 1 { break }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            // ここだけ指で引ける。下の一覧はスクロールさせたいので、板ごとは引かない
            header
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

            ScrollView {
                VStack(spacing: 0) {
                    RecordsSections(
                        entries: entries,
                        records: records,
                        highlight: nil,
                        limit: 5
                    )
                    Button { if !moved { close() } } label: {
                        Text("とじる")
                            .font(DD.bold(14))
                            .foregroundStyle(DD.paper.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .padding(.top, 18)
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, safeBottom + 20)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: maxHeight, alignment: .top)
        .background(DD.brown)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
    }

    private var header: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DD.paper.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            Text("ベストスコア")
                .font(DD.bold(13))
                .tracking(0.52)
                .foregroundStyle(DD.paper.opacity(0.7))
                .padding(.top, 18)

            // ゲーム中・結果画面と同じリールで回す
            RollingNumber(value: displayedBest, size: bestSize)
                .foregroundStyle(DD.paper)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func close() {
        guard !closing else { return }
        closing = true
        withAnimation(reduceMotion ? nil : Self.slideIn) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.24)) { onClose() }
    }
}
