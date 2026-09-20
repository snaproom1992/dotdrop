// 録画を App Store のプレビューの寸法に直す。**Mac でしか動かない。**
//
//   swift ios/tools/preview.swift 入力.mov 出力.mp4 [幅 高さ]
//
// シミュレータの録画は端末そのままの大きさ（6.9インチなら 1320×2868）だが、
// App Store のプレビューは 886×1920 しか受け付けない。縦横の比は
// 0.4603 と 0.4614 でほぼ同じなので、そのまま縮めれば歪みは見て分からない。
//
// ffmpeg は Mac に入っていないので、OS に元からある AVFoundation を使う。
import AVFoundation
import Foundation

let args = CommandLine.arguments
func die(_ m: String) -> Never {
    FileHandle.standardError.write((m + "\n").data(using: .utf8)!)
    exit(1)
}
guard args.count >= 3 else { die("使い方: preview.swift <入力> <出力> [幅 高さ]") }

let src = URL(fileURLWithPath: args[1])
let dst = URL(fileURLWithPath: args[2])
let outW = CGFloat(args.count > 4 ? (Double(args[3]) ?? 886) : 886)
let outH = CGFloat(args.count > 4 ? (Double(args[4]) ?? 1920) : 1920)

let asset = AVURLAsset(url: src)
guard let track = asset.tracks(withMediaType: .video).first else { die("動画が入っていない: \(src.path)") }
let size = track.naturalSize.applying(track.preferredTransform)
let inW = abs(size.width), inH = abs(size.height)
guard inW > 0, inH > 0 else { die("大きさが読めない") }

let comp = AVMutableVideoComposition()
comp.renderSize = CGSize(width: outW, height: outH)
comp.frameDuration = CMTime(value: 1, timescale: 30)

let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
layer.setTransform(track.preferredTransform
    .concatenating(CGAffineTransform(scaleX: outW / inW, y: outH / inH)), at: .zero)
instruction.layerInstructions = [layer]
comp.instructions = [instruction]

guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
    die("書き出せない")
}
try? FileManager.default.removeItem(at: dst)
export.outputURL = dst
export.outputFileType = .mp4
export.videoComposition = comp
export.shouldOptimizeForNetworkUse = true

let done = DispatchSemaphore(value: 0)
export.exportAsynchronously { done.signal() }
done.wait()

if export.status != .completed {
    die("失敗: \(export.error.map { "\($0)" } ?? "理由不明")")
}
let mb = (try? FileManager.default.attributesOfItem(atPath: dst.path)[.size] as? Int)
    .flatMap { $0 } ?? 0
print("  ✓ \(dst.path)  \(Int(outW))×\(Int(outH))  \(mb / 1024 / 1024)MB")
