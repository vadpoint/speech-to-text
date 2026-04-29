import Foundation
import AVFoundation
import Dispatch
import Darwin

func uniqueOutPath() -> String {
    let ts = ISO8601DateFormatter().string(from: Date())
        .replacingOccurrences(of: ":", with: "")
        .replacingOccurrences(of: "-", with: "")
    return "/tmp/ptt_\(ts).wav"
}

func fileSize(_ path: String) -> Int {
    (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue ?? -1
}

var outPath = uniqueOutPath()
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--out"), i + 1 < args.count {
    outPath = args[i + 1]
}
let outURL = URL(fileURLWithPath: outPath)

func makeRecorder(sampleRate: Double) throws -> AVAudioRecorder {
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false
    ]
    return try AVAudioRecorder(url: outURL, settings: settings)
}

var recorder: AVAudioRecorder!

do {
    // 16k сначала, fallback на 48k
    do {
        let r16 = try makeRecorder(sampleRate: 16_000)
        guard r16.prepareToRecord(), r16.record() else { throw NSError() }
        recorder = r16
        print("START \(outPath) SR=16000")
    } catch {
        let r48 = try makeRecorder(sampleRate: 48_000)
        guard r48.prepareToRecord(), r48.record() else {
            fputs("Failed to start recording.\n", stderr)
            exit(2)
        }
        recorder = r48
        print("START \(outPath) SR=48000")
    }
} catch {
    fputs("Recorder init failed: \(error)\n", stderr)
    exit(1)
}
fflush(stdout)

func stopAndExit(_ code: Int32) -> Never {
    recorder.stop()
    Thread.sleep(forTimeInterval: 0.08) // дать дописать WAV заголовок
    let sz = fileSize(outPath)
    print("STOP \(outPath) SIZE=\(sz)")
    fflush(stdout)
    exit(code) // <-- исправлено: Int32
}

// Важно: ловим SIGINT и SIGTERM (hs.task:terminate() шлёт SIGTERM)
signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)

let sigInt = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigInt.setEventHandler { stopAndExit(0) }
sigInt.resume()

let sigTerm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigTerm.setEventHandler { stopAndExit(0) }
sigTerm.resume()

dispatchMain()
