import AVFoundation
import TensorFlowLite

enum PetSoundError: LocalizedError {
    case invalidAudio, invalidModel, invalidScores
    var errorDescription: String? {
        switch self {
        case .invalidAudio: return "0초 초과 120초 이하의 오디오 파일을 선택하세요."
        case .invalidModel: return "소리 분석 모델 형식을 확인할 수 없습니다."
        case .invalidScores: return "소리 분석 결과를 확인할 수 없습니다."
        }
    }
}
enum PetSoundModel {
    static func analyze(_ url: URL) throws -> (Double, [PetSoundWindow]) {
        let file = try AVAudioFile(forReading: url)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        guard duration.isFinite, duration > 0, duration <= 120,
              (1...2).contains(file.processingFormat.channelCount),
              (8000...96000).contains(file.processingFormat.sampleRate),
              file.length * Int64(file.processingFormat.channelCount) <= 16_000_000,
              let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: file.processingFormat, to: format),
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(ceil(duration * 16000)) + 512) else { throw PetSoundError.invalidAudio }
        try file.read(into: input)
        var supplied = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, state in
            if supplied { state.pointee = .endOfStream; return nil }
            supplied = true; state.pointee = .haveData; return input
        }
        if let conversionError { throw conversionError }
        guard status != .error, output.frameLength > 0, let samples = output.floatChannelData?[0] else { throw PetSoundError.invalidAudio }
        guard let model = Bundle.main.path(forResource: "yamnet", ofType: "tflite") else { throw PetSoundError.invalidModel }
        var options = Interpreter.Options(); options.threadCount = 2
        let interpreter = try Interpreter(modelPath: model, options: options)
        try interpreter.allocateTensors()
        guard try interpreter.input(at: 0).shape.dimensions == [15600], try interpreter.output(at: 0).shape.dimensions == [1,521] else { throw PetSoundError.invalidModel }
        let count = Int(output.frameLength)
        var windows: [PetSoundWindow] = []
        for start in stride(from: 0, to: count, by: 7680) {
            var frame = [Float](repeating: 0, count: 15600)
            let length = min(15600, count - start)
            for i in 0..<length { frame[i] = samples[start+i] }
            let data = frame.withUnsafeBufferPointer { Data(buffer: $0) }
            try interpreter.copy(data, toInputAt: 0); try interpreter.invoke()
            let tensor = try interpreter.output(at: 0)
            guard tensor.data.count == 521 * MemoryLayout<Float>.size else { throw PetSoundError.invalidModel }
            var scores = [Float](repeating: 0, count: 521)
            _ = scores.withUnsafeMutableBytes { tensor.data.copyBytes(to: $0) }
            guard scores.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1.00001 }) else { throw PetSoundError.invalidScores }
            windows.append(PetSoundWindow(start: Double(start)/16000, end: min(Double(start+15600)/16000,duration), bark: min(1,Double(scores[70])), dog: min(1,Double(scores[69])), speech: min(1,Double(scores[0]))))
            if start+15600 >= count { break }
        }
        return (duration, windows)
    }
}
