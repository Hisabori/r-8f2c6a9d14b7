import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct NativePetRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let name: String
    let note: String
    let file: String
    let duration: Double
    let windows: [PetSoundWindow]
    var summary: PetPatternSummary? { PetPatterns.summarize(windows, duration: duration) }
}

@MainActor final class NativePetStore: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var records: [NativePetRecord] = []
    @Published private(set) var recording = false
    @Published private(set) var busy = false
    @Published var notice: String?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var healthyStorage = true
    private let folder: URL
    override init() {
        folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("native-pet", isDirectory: true)
        super.init()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let index = folder.appendingPathComponent("records.json")
            if FileManager.default.fileExists(atPath: index.path) { records = try JSONDecoder().decode([NativePetRecord].self, from: Data(contentsOf: index)) }
        } catch { healthyStorage = false; notice = "기존 기록을 읽지 못해 저장을 멈췄습니다. 파일을 보존한 뒤 다시 확인하세요." }
    }
    func start() async {
        guard !recording, !busy, healthyStorage else { return }
        guard !SleepSoundStore.shared.running else { notice = "수면 소리 측정을 먼저 종료하세요."; return }
        busy = true
        defer { busy = false }
        let session = AVAudioSession.sharedInstance()
        let granted = await withCheckedContinuation { continuation in session.requestRecordPermission { continuation.resume(returning: $0) } }
        guard granted else { notice = "설정에서 마이크 권한을 허용하거나 파일 가져오기를 이용하세요."; return }
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
            let value = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            value.delegate = self
            guard value.record() else { throw PetSoundError.invalidAudio }
            recorder = value; recording = true
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let recorder = self.recorder else { return }
                    if recorder.currentTime >= 60 { self.stop() }
                }
            }
        } catch { cleanup(); notice = error.localizedDescription }
    }
    func stop() { guard recording else { return }; recorder?.stop(); cleanup() }
    private func cleanup() {
        timer?.invalidate(); timer = nil; recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        Task { @MainActor in
            self.cleanup()
            guard flag else { self.notice = "녹음을 완료하지 못했습니다."; return }
            self.lastRecording = url
        }
    }
    @Published var lastRecording: URL?
    func analyze(_ source: URL, name: String, note: String) async {
        guard !busy, !recording, healthyStorage else { return }
        busy = true
        defer { busy = false }
        var staged: URL?
        do {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0 && size <= 50 * 1024 * 1024 else { throw PetSoundError.invalidAudio }
            let id = UUID()
            let target = folder.appendingPathComponent(id.uuidString).appendingPathExtension(source.pathExtension.isEmpty ? "m4a" : source.pathExtension)
            try FileManager.default.copyItem(at: source, to: target); staged = target
            let result = try await Task.detached(priority: .userInitiated) { try PetSoundModel.analyze(target) }.value
            let record = NativePetRecord(id: id, date: Date(), name: String(name.prefix(100)), note: String(note.prefix(2000)), file: target.lastPathComponent, duration: result.0, windows: result.1)
            var updated = records; updated.insert(record, at: 0)
            try JSONEncoder().encode(updated).write(to: folder.appendingPathComponent("records.json"), options: [.atomic, .completeFileProtection])
            records = updated; lastRecording = nil
            notice = "분석과 저장을 마쳤습니다. 모델 점수는 정확도나 감정 확률이 아닙니다."
        } catch { if let staged { try? FileManager.default.removeItem(at: staged) }; notice = error.localizedDescription }
    }
}

struct NativePetView: View {
    @StateObject private var store = NativePetStore()
    @State private var importer = false
    @State private var name = ""
    @State private var note = ""
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("소리로 남기는 반려생활").font(.title.bold())
                    Text("녹음하거나 오디오 파일을 가져와 짖음 후보의 흐름을 살펴보세요.").foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 16) {
                    TextField("강아지 이름", text: $name).textFieldStyle(.roundedBorder)
                    TextField("어떤 상황이었나요?", text: $note, axis: .vertical).textFieldStyle(.roundedBorder)
                    Button { if store.recording { store.stop() } else { Task { await store.start() } } } label: {
                        Label(store.recording ? "녹음 종료" : "녹음 시작 · 최대 60초", systemImage: store.recording ? "stop.circle.fill" : "mic.fill").frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.borderedProminent).disabled(store.busy).accessibilityIdentifier("native-pet-record")
                    Button { importer = true } label: { Label("오디오 파일 가져오기", systemImage: "waveform.badge.plus").frame(minHeight: 44) }.disabled(store.busy || store.recording)
                    if let url = store.lastRecording {
                        Button("방금 녹음 분석하기") { Task { await store.analyze(url, name: name, note: note) } }.disabled(store.busy)
                    }
                    if store.busy { ProgressView("기기 안에서 분석하고 있어요") }
                    Text("기존 YAMNet 모델로 소리 후보를 분석합니다. 감정 번역이나 수의학적 진단이 아닙니다. 원음과 기록은 이 기기에 저장돼요.").font(.caption).foregroundStyle(.secondary)
                }.careCard()
                Text("반려생활 기록").font(.title2.bold())
                if store.records.isEmpty { Text("아직 남긴 기록이 없어요.").foregroundStyle(.secondary).careCard() }
                ForEach(store.records) { record in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(record.name.isEmpty ? "소리 기록" : record.name).font(.headline)
                        Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        if let summary = record.summary {
                            Text("짖음 후보 구간 \(summary.eventCount)개 · 묶음 \(summary.boutCount)회")
                            Text(String(format: "후보 지속 시간 %.1f초", summary.activeSeconds)).foregroundStyle(.secondary)
                        }
                        if !record.note.isEmpty { Text(record.note) }
                    }.careCard()
                }
            }.padding(20)
        }.background(CareAppearance.background).navigationTitle("반려생활").navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importer, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url): Task { await store.analyze(url, name: name, note: note) }
            case .failure(let error): store.notice = error.localizedDescription
            }
        }
        .alert("반려생활 안내", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) { Button("확인") { store.notice = nil } } message: { Text(store.notice ?? "") }
        .onDisappear { store.stop() }
        .onChange(of: phase) { if $0 != .active { store.stop() } }
    }
}
