@preconcurrency import AVFoundation

// =====================================================================
// A-2：節目の音。
//
// 釘の音（voice / noise）とは別の楽器・別のバスで鳴らす。
// 残響をかけ、鳴っている間は釘の音を小さくする（ダッキング）。
// 「他の音と混ざって聞き取りづらい」という指摘への対策なので、必ず分けること。
//
// GameAudio.swift 側の受け口（engine / sfx / fan を private から出す、
// build() で残響つきの fan バスを作る）は、このブランチで済ませてある。
// =====================================================================

extension GameAudio {

    // MARK: - 音の高さ

    /// Web の `hz(semi)`。ハ長調のドを基準にした半音
    private func hz(_ semi: Double) -> Double { 261.63 * pow(2, semi / 12) }

    /// 節目の和音。100〜500はハ長調（C→F→G→Am→G7）、
    /// 600で全音上のニ長調へ転調、900のA7から1000でDに解決する。
    /// **段が上がるほど音数と層が増える**のが効くので、数字は変えないこと。
    private static let milestones: [(root: Double, chord: [Double])] = [
        (0,  [0, 4, 7]),        // 100  C
        (5,  [0, 4, 7]),        // 200  F
        (7,  [0, 4, 7]),        // 300  G
        (9,  [0, 3, 7]),        // 400  Am
        (7,  [0, 4, 7, 10]),    // 500  G7
        (2,  [0, 4, 7]),        // 600  D（転調）
        (7,  [0, 4, 7, 9]),     // 700  G6
        (11, [0, 3, 7]),        // 800  Bm
        (9,  [0, 4, 7, 10]),    // 900  A7
        (14, [0, 4, 7, 14]),    // 1000 D（1オクターブ上で解決）
    ]

    // MARK: - 節目ひとそろい

    /// level は 1〜10。100点ごとに1つ上がる
    func playMilestone(level: Int) {
        let L = max(1, min(10, level))
        let m = Self.milestones[L - 1]
        let octave: Double = L >= 6 ? 12 : 0
        let notes = min(9, 3 + L)                          // 100は3音、1000は9音
        let step = max(0.042, 0.085 - Double(L) * 0.0045)  // 段が上がるほど速く
        let base = m.root + octave

        // 1. 駆け上がるアルペジオ（ブラス）
        var last = 0.0
        for i in 0..<notes {
            let semi = base + m.chord[i % m.chord.count] + 12 * Double(i / m.chord.count)
            last = semi
            brass(freq: hz(semi), dur: max(0.07, step * 0.9), gain: 0.075, delay: Double(i) * step)
        }
        let end = Double(notes) * step

        // 2. 最後に和音を長く伸ばす（ブラスの合奏）
        let hold = 0.45 + Double(L) * 0.08
        for c in m.chord { brass(freq: hz(base + c), dur: hold, gain: 0.05, delay: end) }
        brass(freq: hz(last), dur: hold, gain: 0.06, delay: end)
        duck(dur: end + hold + 0.2)

        // 3. 300〜：低音で支える
        if L >= 3 { brass(freq: hz(base - 12), dur: hold + 0.1, gain: 0.06, delay: end) }

        // 4. 500〜：高いきらめきが降ってくる
        if L >= 5 {
            for (i, d) in [0.0, 3, 5, 7, 12].enumerated() {
                bell(freq: hz(last + 12 - d), dur: 0.9, gain: 0.045, delay: end + 0.05 + Double(i) * 0.07)
            }
        }

        // 5. 700〜：うねりが盛り上がってから着地
        if L >= 7 { sweep(dur: end + 0.05, gain: 0.12, from: 400, to: 5000) }

        // 6. 900〜：同じ和音をもう一段、倍速で重ねる
        if L >= 9 {
            for i in 0..<6 {
                bell(freq: hz(base + m.chord[i % m.chord.count] + 24), dur: 0.5, gain: 0.035,
                     delay: end + 0.1 + Double(i) * step * 0.6)
            }
        }

        // 7. 1000：太鼓とシンバルで締める
        if L >= 10 {
            for d in [0.0, 0.12, 0.24] { kick(delay: d, gain: 0.3) }
            kick(delay: end, gain: 0.45)
            sweep(dur: 0.9, gain: 0.18, from: 6000, to: 2500, delay: end)
            for (i, c) in [0.0, 4, 7, 12, 16, 19, 24].enumerated() {
                bell(freq: hz(base + c + 12), dur: 1.8, gain: 0.035, delay: end + 0.02 + Double(i) * 0.03)
            }
            brass(freq: hz(base - 12), dur: 1.4, gain: 0.07, delay: end)
        }
    }

    /// 節目が鳴っている間、釘の音を小さくする
    func duck(dur: Double) {
        guard let sfx else { return }
        sfx.outputVolume = 0.18
        let deadline = DispatchTime.now() + dur
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak sfx] in
            sfx?.outputVolume = 1
        }
    }

    // MARK: - 節目専用の楽器

    /// ブラス：少しずらした2本のノコギリ波＋1オクターブ下の矩形波を、
    /// フィルターを開きながら鳴らす（金管っぽい「パーッ」）
    func brass(freq: Double, dur: Double, gain: Double = 0.1, delay: Double = 0) {
        renderToFan(dur: dur + 0.12, delay: delay) { t, sr in
            // フィルターの開き具合：350 →(0.06秒)→ freq*7 →(dur)→ freq*3.5
            let cutoff: Double
            if t < 0.06 {
                cutoff = 350 * pow(min(6000, freq * 7) / 350, t / 0.06)
            } else {
                let k = min(1, (t - 0.06) / max(0.001, dur - 0.06))
                cutoff = min(6000, freq * 7) * pow(min(3000, freq * 3.5) / min(6000, freq * 7), k)
            }
            // 音量：0.03で立ち上がり、dur-0.08まで保って、0.12かけて消える
            var env: Double
            if t < 0.03 { env = gain * (t / 0.03) }
            else if t < max(0.04, dur - 0.08) { env = gain }
            else {
                let k = min(1, (t - max(0.04, dur - 0.08)) / 0.12)
                env = gain * pow(0.0001 / max(gain, 0.0001), k)
            }
            // ビブラート（5.5Hz、深さは 0.3秒かけて freq*0.006 まで）
            let depth = freq * 0.006 * min(1, t / min(0.3, max(0.001, dur)))
            let vib = sin(2 * .pi * 5.5 * t) * depth
            var s = 0.0
            for cents in [-7.0, 7.0] {
                let f = (freq + vib) * pow(2, cents / 1200)
                let ph = (f * t).truncatingRemainder(dividingBy: 1)
                s += (ph * 2 - 1) * 0.5                       // ノコギリ波
            }
            let subPh = (freq / 2 * t).truncatingRemainder(dividingBy: 1)
            s += (subPh < 0.5 ? 1.0 : -1.0) * 0.25            // 1オクターブ下の矩形波
            return (s * env, cutoff / (sr * 0.5))             // 第2要素がローパスの強さ
        }
    }

    /// ベル：FM合成の金属的な「キーン」。きらめき用
    func bell(freq: Double, dur: Double, gain: Double = 0.05, delay: Double = 0) {
        let modFreq = freq * 3.5
        renderToFan(dur: dur, delay: delay) { t, _ in
            let k = min(1, t / max(0.001, dur))
            // 変調の深さ（Hz）。freq*2.2 から freq*0.05 へ落ちていく
            let index = freq * 2.2 * pow(0.05 / 2.2, k)
            // 周波数変調を位相で書くと、変調波の積分になる
            let phase = 2 * .pi * freq * t - (index / modFreq) * cos(2 * .pi * modFreq * t)
            let env = gain * pow(0.0001 / max(gain, 0.0001), k)
            return (sin(phase) * env, 1)
        }
    }

    /// うねり：ノイズを細い帯に絞って、低い→高いへ動かす
    func sweep(dur: Double, gain: Double, from: Double, to: Double, delay: Double = 0) {
        var lp = 0.0, bp = 0.0
        renderToFan(dur: dur, delay: delay) { t, sr in
            let k = min(1, t / max(0.001, dur))
            let f = from * pow(to / from, k)
            // 音量：dur*0.85 まで上がって、そこから落ちる（どちらも指数）
            let g = max(gain, 0.0001)
            let env: Double = k < 0.85
                ? 0.0001 * pow(g / 0.0001, k / 0.85)
                : g * pow(0.0001 / g, (k - 0.85) / 0.15)
            // 2極のバンドパス（Q=3 相当）
            let white = Double.random(in: -1...1)
            let g = min(0.99, 2 * sin(.pi * min(f, sr * 0.45) / sr))
            let q = 1.0 / 3.0
            lp += g * bp
            let hp = white - lp - q * bp
            bp += g * hp
            return (bp * env, 1)
        }
    }

    /// 太鼓：140Hz から 45Hz へ一気に落ちるサイン波
    func kick(delay: Double = 0, gain: Double = 0.35) {
        var phase = 0.0
        renderToFan(dur: 0.32, delay: delay) { t, sr in
            let f = 140 * pow(45.0 / 140.0, min(1, t / 0.22))
            phase += 2 * .pi * f / sr
            let env = gain * pow(0.0001 / max(gain, 0.0001), min(1, t / 0.3))
            return (sin(phase) * env, 1)
        }
    }

    // MARK: - 合成して節目バスへ流す

    /// `body` は (経過秒, サンプリング周波数) を受け取り、
    /// (そのサンプルの値, ローパスの強さ 0〜1。1なら素通し) を返す。
    private func renderToFan(
        dur: Double, delay: Double,
        _ body: (Double, Double) -> (Double, Double)
    ) {
        unlock()
        guard let eng = engine, let fan, eng.isRunning else { return }
        let format = fan.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        let sr = format.sampleRate
        let frames = AVAudioFrameCount((dur + delay + 0.02) * sr)
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buf.frameLength = frames
        guard let data = buf.floatChannelData?[0] else { return }

        let delayN = Int(delay * sr)
        let n = Int(dur * sr)
        for i in 0..<Int(frames) { data[i] = 0 }
        var lp = 0.0
        for i in 0..<n {
            let idx = delayN + i
            if idx >= Int(frames) { break }
            let (raw, cut) = body(Double(i) / sr, sr)
            // ローパス（cut が 1 なら素通し）
            let a = max(0.0001, min(1, cut))
            lp += a * (raw - lp)
            let s = a >= 1 ? raw : lp
            data[idx] += Float(max(-1, min(1, s)))
        }

        let player = AVAudioPlayerNode()
        eng.attach(player)
        eng.connect(player, to: fan, format: format)
        nonisolated(unsafe) let unsafeEng = eng
        nonisolated(unsafe) let unsafePlayer = player
        player.scheduleBuffer(buf, completionHandler: {
            Task { @MainActor in unsafeEng.detach(unsafePlayer) }
        })
        player.play()
    }
}
