import SwiftUI

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

    var body: some View {
        VStack(spacing: 0) {
            section("ランキング") { ranking }
            section("これまでの記録") { recordGrid }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
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
                        Text("\(i + 1)")
                            .font(DD.bold(14))
                            .opacity(0.7)
                            .frame(width: 28, alignment: .leading)
                        Text("\(r.score)")
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
                    Text("\(records[item.key] ?? 0)")
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

/// タイトルから開く「きろく」。結果画面と違って今回の回がないので、
/// マスタードの塗りはなし。上位10件まで出す
struct RecordsScreen: View {
    var safeTop: CGFloat
    var safeBottom: CGFloat
    var onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            DD.brown.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Text("きろく")
                        .font(DD.bold(22))
                        .foregroundStyle(DD.paper)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    RecordsSections(
                        entries: DDStore.ranking(),
                        records: DDStore.records(),
                        highlight: nil,
                        limit: 10
                    )
                    Button(action: onClose) {
                        Text("とじる")
                            .font(DD.bold(14))
                            .foregroundStyle(DD.paper.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .padding(.top, 24)
                }
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, safeTop + 28)
                .padding(.bottom, safeBottom + 40)
            }
            .scrollIndicators(.hidden)
        }
    }
}
