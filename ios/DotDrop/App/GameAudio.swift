@preconcurrency import AVFoundation
import UIKit
import DotDropEngine

/// Web Audio の sfx 相当（voice / noise / note）。ファイルなしで合成。
@MainActor
final class GameAudio {
    static let shared = GameAudio()

    // 節目の音（MilestoneAudio.swift）から触るので private にしない
    var engine: AVAudioEngine?
    var sfx: AVAudioMixerNode?
    /// 節目の音だけを通すバス。残響がかかる
    var fan: AVAudioMixerNode?
    /// ダッキングの通し番号。節目が続けて鳴ったとき、古いほうの戻しを無視するのに使う
    var duckSeq: UInt = 0
    private var voices = 0
    private let penta = [0, 2, 4, 7, 9]

    func unlock() {
        if engine == nil { build() }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        engine?.prepare()
        try? engine?.start()
    }

    private func build() {
        let eng = AVAudioEngine()
        let mix = AVAudioMixerNode()        // 釘の音
        let fanMix = AVAudioMixerNode()     // 節目の音
        // 節目にだけ残響をかける。釘の音まで濡らすと、当たった粒立ちが消える
        let verb = AVAudioUnitReverb()
        verb.loadFactoryPreset(.mediumHall)
        verb.wetDryMix = 28
        eng.attach(mix)
        eng.attach(fanMix)
        eng.attach(verb)
        eng.connect(mix, to: eng.mainMixerNode, format: nil)
        eng.connect(fanMix, to: verb, format: nil)
        eng.connect(verb, to: eng.mainMixerNode, format: nil)
        eng.mainMixerNode.outputVolume = 1
        engine = eng
        sfx = mix
        fan = fanMix
    }

    func note(_ n: Int, fever: Bool) -> Double {
        let i = min(max(n, 1) - 1, 14)
        let semi = 12 * (i / 5) + penta[i % 5] + (fever ? 5 : 0)
        return 392 * pow(2.0, Double(semi) / 12.0)
    }

    /// 音の形。本家の `voice(freq, dur, gain, type)` の type にあたる。
    /// **これを間違えると別の音になる。**とくに減る受け皿の「ブー」はノコギリ波でしか出ない
    enum Wave {
        case triangle, sine, square, sawtooth
        func sample(_ phase: Double) -> Double {
            switch self {
            case .sine: return sin(phase)
            case .square: return phase.truncatingRemainder(dividingBy: 2 * .pi) < .pi ? 1 : -1
            case .sawtooth: return (phase / (2 * .pi)).truncatingRemainder(dividingBy: 1) * 2 - 1
            case .triangle: return abs((phase / .pi).truncatingRemainder(dividingBy: 2) - 1) * 2 - 1
            }
        }
    }

    func voice(freq: Double, dur: Double, gain: Double = 0.1, wave: Wave = .triangle, delay: Double = 0) {
        unlock()
        guard let eng = engine, let sfx, voices < 90, eng.isRunning else { return }
        let format = sfx.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        let sr = format.sampleRate
        let total = dur + delay + 0.02
        let frames = AVAudioFrameCount(total * sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buf.frameLength = frames
        guard let chans = buf.floatChannelData else { return }

        let channels = Int(format.channelCount)
        let delayN = Int(delay * sr)
        for ch in 0..<channels {
            let d = chans[ch]
            for i in 0..<Int(frames) { d[i] = 0 }
        }
        let layers: [(Double, Double)] = [(1, gain), (2, gain * 0.35), (4.01, gain * 0.12)]
        for (mul, g) in layers {
            let f = freq * mul
            let layerDur = mul > 1 ? dur * 0.4 : dur
            let layerN = Int(layerDur * sr)
            for i in 0..<layerN {
                let t = Double(i) / sr
                var env = g
                if t < 0.004 { env = g * (t / 0.004) }
                else {
                    let k = (t - 0.004) / max(0.001, layerDur - 0.004)
                    env = g * max(0.0001, pow(0.0001 / max(g, 0.0001), min(1, k)))
                }
                let phase = 2 * Double.pi * f * t
                // 形が付くのは基音だけ。下の層はいつもサイン（本家と同じ）
                let sample = Float((mul == 1 ? wave.sample(phase) : sin(phase)) * env)
                let idx = delayN + i
                if idx < Int(frames) {
                    // 左右の両方に書く。片方だけだと半分の大きさに聞こえる
                    for ch in 0..<channels { chans[ch][idx] += sample }
                }
            }
        }

        let player = AVAudioPlayerNode()
        eng.attach(player)
        eng.connect(player, to: sfx, format: format)
        voices += 1
        // AVAudio* は Sendable でないので、完了コールバックへ渡す参照は nonisolated(unsafe)
        nonisolated(unsafe) let unsafeEng = eng
        nonisolated(unsafe) let unsafePlayer = player
        player.scheduleBuffer(buf, completionHandler: { [weak self] in
            Task { @MainActor in
                unsafeEng.detach(unsafePlayer)
                self?.voices = max(0, (self?.voices ?? 1) - 1)
            }
        })
        player.play()
    }

    func noise(dur: Double, gain: Double = 0.15, freq: Double = 900) {
        unlock()
        guard let eng = engine, let sfx, eng.isRunning else { return }
        let format = sfx.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        let sr = format.sampleRate
        let frames = AVAudioFrameCount(dur * sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buf.frameLength = frames
        guard let chans = buf.floatChannelData else { return }
        let channels = Int(format.channelCount)
        // 簡易バンドパスっぽくノイズを減衰
        var lp = 0.0
        let a = min(1, freq / (sr * 0.5))
        for i in 0..<Int(frames) {
            let white = Double.random(in: -1...1)
            lp += a * (white - lp)
            let env = (1 - Double(i) / Double(frames)) * gain
            let s = Float(lp * env)
            for ch in 0..<channels { chans[ch][i] = s }
        }
        let player = AVAudioPlayerNode()
        eng.attach(player)
        eng.connect(player, to: sfx, format: format)
        nonisolated(unsafe) let unsafeEng = eng
        nonisolated(unsafe) let unsafePlayer = player
        player.scheduleBuffer(buf, completionHandler: {
            Task { @MainActor in unsafeEng.detach(unsafePlayer) }
        })
        player.play()
    }

    func playHit(kind: PegKind, hitCount: Int, fever: Bool) {
        let n = note(hitCount, fever: fever)
        switch kind {
        case .dot:
            voice(freq: n, dur: 0.3, gain: 0.08)
        case .square:
            voice(freq: n / 2, dur: 0.18, gain: 0.12, wave: .square)
            noise(dur: 0.06, gain: 0.2, freq: 2400)
            voice(freq: n, dur: 0.3, gain: 0.08)
        case .blue:
            voice(freq: n, dur: 0.8, gain: 0.1, wave: .sine)
            voice(freq: n * 1.5, dur: 0.8, gain: 0.06, wave: .sine, delay: 0.08)
        case .tri:
            for (k, s) in [0, 4, 7, 12].enumerated() {
                let f = n * pow(2.0, Double(s) / 12.0)
                voice(freq: f, dur: 0.35, gain: 0.08, delay: Double(k) * 0.04)
            }
            noise(dur: 0.08, gain: 0.12, freq: 4000)
        }
    }

    func playShoot() {
        voice(freq: 880, dur: 0.1, gain: 0.08)
        noise(dur: 0.05, gain: 0.1, freq: 1500)
    }

    func playStart() {
        voice(freq: note(1, fever: false), dur: 0.2, gain: 0.08)
        voice(freq: note(3, fever: false), dur: 0.2, gain: 0.08, delay: 0.08)
        voice(freq: note(5, fever: false), dur: 0.3, gain: 0.08, delay: 0.16)
    }

    // 節目の音（playMilestone）は MilestoneAudio.swift にある。
    // **釘の音と同じ voice/noise で鳴らしてはいけない。**同じ経路・同じ楽器だと必ず埋もれる。
    // 別のバス（fan）に、ブラスとベルで、残響をかけて鳴らし、その間は釘の音を下げる

    func playPerfect() {
        duck(dur: 1.6)
        let C = 261.63
        for (i, sp) in [0, 4, 7, 12].enumerated() {
            voice(freq: C * pow(2.0, Double(sp) / 12.0), dur: 0.52, gain: 0.1, delay: Double(i) * 0.09)
        }
        for (i, sp) in [12, 16, 19, 24].enumerated() {
            voice(freq: C * pow(2.0, Double(sp) / 12.0), dur: 0.62, gain: 0.09, delay: 0.52 + Double(i) * 0.1)
        }
        noise(dur: 0.3, gain: 0.15, freq: 800)
        // 歓声。ノイズを帯で絞っただけでは「サー」にしかならないので、
        // 大勢の「わー」と拍手を作って鳴らす（MilestoneAudio.swift）
        cheer()
    }

    func playFever() {
        for (k, sp) in [0, 4, 7, 12, 16, 19, 24].enumerated() {
            voice(freq: note(1, fever: false) * pow(2.0, Double(sp) / 12.0), dur: 0.4, gain: 0.07, wave: .square, delay: Double(k) * 0.06)
        }
    }

    func playNewRecord() {
        for (k, s) in [0, 4, 7, 12].enumerated() {
            voice(freq: note(6, fever: false) * pow(2.0, Double(s) / 12.0), dur: 0.35, gain: 0.07, wave: .square, delay: Double(k) * 0.07)
        }
    }
}

@MainActor
enum GameHaptics {
    private static var last: CFTimeInterval = 0
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)

    static func prepare() {
        light.prepare(); medium.prepare(); heavy.prepare()
    }

    static func buzz(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light, gap: CFTimeInterval = 0.045) {
        let now = CACurrentMediaTime()
        if now - last < gap { return }
        last = now
        switch style {
        case .medium: medium.impactOccurred()
        case .heavy: heavy.impactOccurred()
        default: light.impactOccurred()
        }
    }

    static func pattern(_ times: Int, intervalMs: Int) {
        for i in 0..<times {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(i * intervalMs)) {
                buzz(.medium, gap: 0)
            }
        }
    }
}
