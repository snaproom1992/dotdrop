@preconcurrency import AVFoundation
import UIKit
import DotDropEngine

/// Web Audio の sfx 相当（voice / noise / note）。ファイルなしで合成。
@MainActor
final class GameAudio {
    static let shared = GameAudio()

    private var engine: AVAudioEngine?
    private var sfx: AVAudioMixerNode?
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
        let mix = AVAudioMixerNode()
        eng.attach(mix)
        eng.connect(mix, to: eng.mainMixerNode, format: nil)
        eng.mainMixerNode.outputVolume = 0.9
        engine = eng
        sfx = mix
    }

    func note(_ n: Int, fever: Bool) -> Double {
        let i = min(max(n, 1) - 1, 14)
        let semi = 12 * (i / 5) + penta[i % 5] + (fever ? 5 : 0)
        return 392 * pow(2.0, Double(semi) / 12.0)
    }

    func voice(freq: Double, dur: Double, gain: Double = 0.1, delay: Double = 0) {
        unlock()
        guard let eng = engine, let sfx, voices < 90, eng.isRunning else { return }
        let format = sfx.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        let sr = format.sampleRate
        let total = dur + delay + 0.02
        let frames = AVAudioFrameCount(total * sr)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buf.frameLength = frames
        guard let data = buf.floatChannelData?[0] else { return }

        let delayN = Int(delay * sr)
        for i in 0..<Int(frames) {
            data[i] = 0
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
                // triangle-ish
                let tri = abs((phase / Double.pi).truncatingRemainder(dividingBy: 2) - 1) * 2 - 1
                let sample = mul == 1 ? Float(tri * env) : Float(sin(phase) * env)
                let idx = delayN + i
                if idx < Int(frames) { data[idx] += sample }
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
        guard let data = buf.floatChannelData?[0] else { return }
        // 簡易バンドパスっぽくノイズを減衰
        var lp = 0.0
        let a = min(1, freq / (sr * 0.5))
        for i in 0..<Int(frames) {
            let white = Double.random(in: -1...1)
            lp += a * (white - lp)
            let env = (1 - Double(i) / Double(frames)) * gain
            data[i] = Float(lp * env)
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
            voice(freq: n / 2, dur: 0.18, gain: 0.12)
            noise(dur: 0.06, gain: 0.2, freq: 2400)
            voice(freq: n, dur: 0.3, gain: 0.08)
        case .blue:
            voice(freq: n, dur: 0.8, gain: 0.1)
            voice(freq: n * 1.5, dur: 0.8, gain: 0.06, delay: 0.08)
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

    /// 100点ごとのファンファーレ（Web playMilestone の簡略版）
    func playMilestone(level: Int) {
        let L = level
        let root = 261.63 * pow(2.0, Double(L >= 6 ? 12 : 0) / 12.0)
        let chord = [0, 4, 7, 12]
        let notes = min(9, 3 + L)
        let step = max(0.042, 0.085 - Double(L) * 0.0045)
        for i in 0..<notes {
            let semi = chord[i % chord.count] + 12 * (i / chord.count)
            let f = root * pow(2.0, Double(semi) / 12.0)
            voice(freq: f, dur: max(0.07, step * 0.9), gain: 0.075, delay: Double(i) * step)
        }
        let end = Double(notes) * step
        for c in chord {
            let f = root * pow(2.0, Double(c) / 12.0)
            voice(freq: f, dur: 0.45 + Double(L) * 0.08, gain: 0.05, delay: end)
        }
        if L >= 5 {
            for (i, off) in [0, 3, 5, 7, 12].enumerated() {
                let f = root * pow(2.0, Double(12 + chord[0] + 12 - off) / 12.0)
                voice(freq: f, dur: 0.5, gain: 0.04, delay: end + 0.05 + Double(i) * 0.07)
            }
        }
        if L >= 10 {
            noise(dur: 0.12, gain: 0.18, freq: 200)
            noise(dur: 0.18, gain: 0.12, freq: 4000)
        }
    }

    func playPerfect() {
        let C = 261.63
        for (i, sp) in [0, 4, 7, 12].enumerated() {
            voice(freq: C * pow(2.0, Double(sp) / 12.0), dur: 0.52, gain: 0.1, delay: Double(i) * 0.09)
        }
        for (i, sp) in [12, 16, 19, 24].enumerated() {
            voice(freq: C * pow(2.0, Double(sp) / 12.0), dur: 0.62, gain: 0.09, delay: 0.52 + Double(i) * 0.1)
        }
        noise(dur: 0.3, gain: 0.15, freq: 800)
        // 歓声っぽい帯
        noise(dur: 0.8, gain: 0.1, freq: 1200)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.noise(dur: 0.6, gain: 0.08, freq: 900)
        }
    }

    func playFever() {
        for (k, sp) in [0, 4, 7, 12, 16, 19, 24].enumerated() {
            voice(freq: note(1, fever: false) * pow(2.0, Double(sp) / 12.0), dur: 0.4, gain: 0.07, delay: Double(k) * 0.06)
        }
    }

    func playNewRecord() {
        for (k, s) in [0, 4, 7, 12].enumerated() {
            voice(freq: note(6, fever: false) * pow(2.0, Double(s) / 12.0), dur: 0.35, gain: 0.07, delay: Double(k) * 0.07)
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
