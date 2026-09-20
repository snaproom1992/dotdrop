import Foundation

/// 端末に残す記録。本家の `localStorage` と同じ中身・同じキーにしてある
/// （`dotdrop-ranking` ＝上位10件、`dotdrop-records` ＝項目ごとの最高）。
///
/// **チュートリアルの記録とは混ぜない。**ここはフリープレイのもの。
enum DDStore {

    struct RankEntry: Codable, Equatable {
        var score: Int
        var stage: Int
        var shots: Int
        var date: Date
    }

    /// 本家の `REC_KEYS`。並び順もそのまま
    static let recordLabels: [(key: String, label: String)] = [
        ("shotScore", String(localized: "1回の最高スコア")),
        ("shotBalls", String(localized: "1回で増えた玉の最大数")),
        ("shotHits", String(localized: "1回の最多ヒット")),
        ("ballGain", String(localized: "1球の最高獲得スコア")),
        ("gameScore", String(localized: "1ゲームの最高スコア")),
        ("peakMoney", String(localized: "持ち玉の最高記録")),
        ("stage", String(localized: "到達したステージ")),
    ]

    private static let rankKey = "dotdrop-ranking"
    private static let recKey = "dotdrop-records"

    // MARK: - ランキング

    static func ranking() -> [RankEntry] {
        guard let data = UserDefaults.standard.data(forKey: rankKey),
              let list = try? JSONDecoder().decode([RankEntry].self, from: data) else { return [] }
        return list
    }

    /// 入れて並べ替え、上位10件だけ残す。戻り値は入った順位（0 始まり）。入らなければ -1
    static func addRanking(_ entry: RankEntry) -> Int {
        var list = ranking()
        list.append(entry)
        list.sort { $0.score > $1.score }
        list = Array(list.prefix(10))
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: rankKey)
        }
        return list.firstIndex(of: entry) ?? -1
    }

    // MARK: - 項目ごとの最高

    static func records() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: recKey) as? [String: Int] ?? [:]
    }

    /// これまでより大きければ書き換える。戻り値は「前にも記録があって、それを超えた」かどうか
    @discardableResult
    static func bump(_ key: String, _ value: Int) -> Bool {
        var all = records()
        let had = all[key] ?? 0
        guard value > had else { return false }
        all[key] = value
        UserDefaults.standard.set(all, forKey: recKey)
        return had > 0
    }
}
