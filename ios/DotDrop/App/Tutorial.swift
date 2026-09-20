import SwiftUI
import DotDropEngine

/// 訳を引くだけ。`%@` を書式として処理させたくない文に使う（あそびかたのやること）
private func locRaw(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

/// The eight lessons from index.html STEPS. Tutorial records never enter free-play rankings.
struct TutorialStep: Identifiable {
    enum Goal { case shots, multiplier, gain, hit(PegKind), balls, shotScore, fever }
    let id: String
    let title: String
    let symbol: String
    let color: Color
    let hint: String
    let seed: Int
    let layout: Int
    let goal: Goal
    let target: Int
    let config: EngineConfig

    /// `title` は訳ずみの文。記号を置く場所に `%@` が入っている（英語は語順が逆になるため）
    func titleText(_ base: Color = DD.paper) -> Text {
        guard let slot = title.range(of: "%@") else { return Text(title).foregroundColor(base) }
        return Text(String(title[..<slot.lowerBound])).foregroundColor(base)
            + Text(symbol).foregroundColor(color)
            + Text(String(title[slot.upperBound...])).foregroundColor(base)
    }

    /// 読み上げ用。記号を文字のまま入れた1本の文
    var plainTitle: String { title.replacingOccurrences(of: "%@", with: symbol) }

    static let all: [TutorialStep] = {
        func conf(_ start: Int, easy: Bool = false, plus: Bool = false,
                  squares: Int = 3, blues: Int = 2, tris: Int = 3) -> EngineConfig {
            var c = EngineConfig.freePlay
            c.startBalls = start; c.perfect = 0
            c.squares = squares; c.blues = blues; c.tris = tris
            c.stageB = [plus ? [0, 1, 0, 2, 0, 1, 0, 2, 0, 1, 0, 2, 0, 1, 0, 2] : Array(repeating: 0, count: 16)]
            if easy { c.slotM = (0..<16).map { $0 % 2 == 0 ? 1 : 3 } }
            return c
        }
        return [
            .init(id: "shot", title: String(localized: "玉を打つ"), symbol: "", color: DD.paper, hint: String(localized: "画面を引っ張って、はなす"), seed: 11, layout: 0, goal: .shots, target: 1, config: conf(3)),
            .init(id: "mult3", title: locRaw("%@ に入れる"), symbol: "×3", color: DD.mustard, hint: String(localized: "入ると、スコアが3倍になる"), seed: 23, layout: 2, goal: .multiplier, target: 3, config: conf(5, easy: true)),
            .init(id: "gain", title: String(localized: "持ち玉を増やす"), symbol: "", color: DD.paper, hint: String(localized: "● の数だけ持ち玉が戻ってくる"), seed: 31, layout: 0, goal: .gain, target: 3, config: conf(4, plus: true)),
            .init(id: "square", title: locRaw("%@ に当てる"), symbol: "■", color: DD.red, hint: String(localized: "赤い四角は強くはね返す"), seed: 5, layout: 0, goal: .hit(.square), target: 1, config: conf(4, squares: 8, blues: 0, tris: 0)),
            .init(id: "blue", title: locRaw("%@ につかまる"), symbol: "●", color: DD.blue, hint: String(localized: "青い円は玉をつかまえて放す"), seed: 7, layout: 0, goal: .hit(.blue), target: 1, config: conf(4, squares: 0, blues: 8, tris: 0)),
            .init(id: "tri5", title: locRaw("%@ で玉を5つにする"), symbol: "▲", color: DD.mustard, hint: String(localized: "黄色い三角に当たると3つに分かれる"), seed: 13, layout: 0, goal: .balls, target: 5, config: conf(5, squares: 0, blues: 0, tris: 8)),
            .init(id: "p100", title: String(localized: "1回で100点"), symbol: "", color: DD.paper, hint: String(localized: "たくさん当てるほどポイントが増える"), seed: 17, layout: 0, goal: .shotScore, target: 100, config: conf(6, easy: true, squares: 4, tris: 6)),
            .init(id: "fever", title: String(localized: "フィーバーに入る"), symbol: "", color: DD.paper, hint: String(localized: "ポイントがたまると入れる"), seed: 19, layout: 2, goal: .fever, target: 1, config: conf(8, easy: true, squares: 4, tris: 6))
        ]
    }()
}

struct TutorialOverlay: View {
    var session: GameSession
    var safeTop: CGFloat
    var safeBottom: CGFloat

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if session.screen == .tutorialResult {
                    Image(systemName: session.tutorialSucceeded ? "checkmark" : "minus")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(session.tutorialSucceeded ? DD.red : DD.paper.opacity(0.3))
                        .accessibilityHidden(true)
                    Text(session.tutorialSucceeded ? "CLEAR" : "玉切れ")
                        .font(DD.bold(13)).padding(.top, 10)
                    dots.padding(.top, 22)
                    if session.tutorialSucceeded, let index = session.tutorialIndex, index + 1 < TutorialStep.all.count {
                        Text("NEXT").font(DD.bold(13)).opacity(0.55)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 30)
                        lessonRow(index + 1).padding(.top, 6)
                    } else {
                        Button(session.tutorialSucceeded ? "ゲームをはじめる" : "もう一度") {
                            if session.tutorialSucceeded { session.startFreePlay() }
                            else if let index = session.tutorialIndex { session.startTutorial(index) }
                        }
                        .buttonStyle(LessonPrimaryStyle()).padding(.top, 28)
                    }
                    Button("一覧") { session.openTutorialList() }
                        .font(DD.bold(13)).padding(.top, 20).frame(minHeight: 44)
                } else {
                    Text("あそびかた").font(DD.bold(13)).opacity(0.7).padding(.bottom, 24)
                    ForEach(TutorialStep.all.indices, id: \.self) { lessonRow($0) }
                    Button("もどる") { session.openTitle() }
                        .font(DD.bold(13)).padding(.top, 28).frame(minHeight: 44)
                }
            }
            .foregroundStyle(DD.paper)
            .frame(maxWidth: 310)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, safeTop + 40)
            .padding(.bottom, safeBottom + 40)
        }
        .background(DD.brown)
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(TutorialStep.all) { step in
                Circle().fill(session.tutorialCleared.contains(step.id) ? DD.red : DD.paper.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel(Text("8項目中\(session.tutorialCleared.count)項目クリア"))
    }

    private func lessonRow(_ index: Int) -> some View {
        let step = TutorialStep.all[index]
        let done = session.tutorialCleared.contains(step.id)
        return Button { session.startTutorial(index) } label: {
            HStack(spacing: 10) {
                Text("\(index + 1)").font(DD.bold(19)).kerning(-0.57)
                    .opacity(0.45).frame(width: 26, alignment: .leading)
                step.titleText().font(DD.bold(16)).opacity(done ? 0.5 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: done && session.screen == .tutorialList ? "checkmark" : "chevron.right")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(DD.red).frame(width: 24)
            }
            .padding(.vertical, 15)
            .overlay(alignment: .top) { Rectangle().fill(DD.paper.opacity(0.14)).frame(height: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(index + 1). \(step.plainTitle)\(done ? String(localized: "。クリア済み") : "")"))
    }
}

private struct LessonPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(DD.bold(18)).foregroundStyle(DD.paper)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(DD.red.opacity(configuration.isPressed ? 0.7 : 1)).clipShape(Capsule())
    }
}
