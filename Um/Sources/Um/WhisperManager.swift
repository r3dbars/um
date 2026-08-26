import AVFoundation
import Combine
import SwiftWhisper
import UmCore
import os

private let logger = Logger(subsystem: "com.r3dbars.um", category: "WhisperManager")

/// Captures microphone audio and transcribes it locally with whisper.cpp.
/// Filler words stay in the transcript, which Apple's speech API often drops.
final class WhisperManager: NSObject, ObservableObject {
    static let shared = WhisperManager()

    static let modelFileName = "ggml-tiny.en.bin"

    @Published var isListening = false
    @Published var errorMessage: String?
    @Published var isModelAvailable = false

    private let audioEngine = AVAudioEngine()
    private let counter = FillerWordCounter.shared
    private var whisper: Whisper?

    private let bufferLock = NSLock()
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16_000
    private var transcribeTimer: Timer?
    private var tapInstalled = false
    private var startInFlight = false

    private let transcribeInterval: TimeInterval = 3.0

    override init() {
        super.init()
        loadModel()
    }

    // MARK: - Model

    func loadModel() {
        guard let url = Self.locateModel() else {
            logger.error("Whisper model not found")
            isModelAvailable = false
            errorMessage = "Whisper model not found. Place \(Self.modelFileName) in the models/ folder or run scripts/download-model.sh."
            return
        }

        logger.info("Loading model at \(url.path, privacy: .private)")
        let params = WhisperParams(strategy: .greedy)
        params.language = .english
        params.no_context = true
        whisper = Whisper(fromFileURL: url, withParams: params)
        isModelAvailable = whisper != nil
        if whisper != nil {
            errorMessage = nil
            logger.info("Whisper model loaded")
        } else {
            errorMessage = "Failed to load the Whisper model."
        }
    }

    static func locateModel() -> URL? {
        let names = [modelFileName, "ggml-base.en.bin"]
        var candidates: [URL] = []

        if let resource = Bundle.main.resourceURL {
            for name in names {
                candidates.append(resource.appendingPathComponent(name))
            }
        }

        if let exe = Bundle.main.executableURL {
            let macos = exe.deletingLastPathComponent()
            let contents = macos.deletingLastPathComponent()
            for name in names {
                candidates.append(contents.appendingPathComponent("Resources/\(name)"))
                candidates.append(macos.appendingPathComponent("models/\(name)"))
            }
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for name in names {
            candidates.append(cwd.appendingPathComponent("models/\(name)"))
        }

        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for name in names {
                candidates.append(support.appendingPathComponent("Um/\(name)"))
            }
        }

        candidates.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("models/\(modelFileName)"))

        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path) {
                logger.info("Found model at \(url.path, privacy: .private)")
                return url
            }
        }
        return nil
    }

    // MARK: - Permissions

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    // MARK: - Start / Stop

    func startListening() {
        if whisper == nil {
            loadModel()
        }
        guard whisper != nil else {
            logger.error("Cannot start — Whisper model not loaded")
            return
        }
        guard !audioEngine.isRunning, !startInFlight else {
            logger.debug("Audio engine already running")
            return
        }

        startInFlight = true
        requestMicrophoneAccess { [weak self] granted in
            guard let self else { return }
            self.startInFlight = false
            if granted {
                self.beginCapture()
            } else {
                self.errorMessage = "Microphone access is required. Enable it in System Settings → Privacy & Security → Microphone."
            }
        }
    }

    /// Stops the mic and timer only. Does not end the filler-word session.
    func stopCapture() {
        transcribeTimer?.invalidate()
        transcribeTimer = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        transcribeBuffer()
        bufferLock.lock()
        audioBuffer.removeAll()
        bufferLock.unlock()
        DispatchQueue.main.async {
            self.isListening = false
            logger.info("Whisper capture stopped")
        }
    }

    private func beginCapture() {
        logger.info("Starting audio capture")

        do {
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            logger.info("Input format: sampleRate=\(inputFormat.sampleRate), channels=\(inputFormat.channelCount)")

            guard let convertFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            ) else {
                logger.error("Failed to create conversion format")
                DispatchQueue.main.async { self.errorMessage = "Could not configure audio." }
                return
            }

            guard let converter = AVAudioConverter(from: inputFormat, to: convertFormat) else {
                logger.error("Failed to create audio converter")
                DispatchQueue.main.async { self.errorMessage = "Could not configure audio." }
                return
            }

            if tapInstalled {
                inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                self?.convertAndAppend(buffer: buffer, converter: converter, outputFormat: convertFormat)
            }
            tapInstalled = true

            audioEngine.prepare()
            try audioEngine.start()

            bufferLock.lock()
            audioBuffer.removeAll()
            bufferLock.unlock()

            transcribeTimer = Timer.scheduledTimer(withTimeInterval: transcribeInterval, repeats: true) { [weak self] _ in
                self?.transcribeBuffer()
            }
            RunLoop.main.add(transcribeTimer!, forMode: .common)

            DispatchQueue.main.async {
                self.isListening = true
                self.errorMessage = nil
                logger.info("Whisper capture started")
            }
        } catch {
            if tapInstalled {
                audioEngine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Mic error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Audio Conversion

    private func convertAndAppend(buffer: AVAudioPCMBuffer,
                                  converter: AVAudioConverter,
                                  outputFormat: AVAudioFormat) {
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate
        )
        guard frameCount > 0 else { return }
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }

        var error: NSError?
        var consumed = false
        converter.convert(to: convertedBuffer, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }

        if let error {
            logger.warning("Audio conversion error: \(error.localizedDescription)")
            return
        }

        guard let floatData = convertedBuffer.floatChannelData else { return }
        let samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(convertedBuffer.frameLength)))
        bufferLock.lock()
        audioBuffer.append(contentsOf: samples)
        bufferLock.unlock()
    }

    // MARK: - Transcription

    private func transcribeBuffer() {
        guard let whisper else { return }

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer.removeAll()
        bufferLock.unlock()

        guard samples.count > Int(sampleRate * 0.5) else { return }
        guard whisper.inProgress == false else {
            bufferLock.lock()
            audioBuffer.insert(contentsOf: samples, at: 0)
            bufferLock.unlock()
            return
        }

        let duration = Double(samples.count) / sampleRate
        logger.info("Transcribing \(String(format: "%.1f", duration), privacy: .private)s of audio")

        Task {
            do {
                let segments = try await whisper.transcribe(audioFrames: samples)
                let transcript = segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
                let cleaned = TranscriptCleaning.cleaned(transcript)
                if !cleaned.isEmpty {
                    logger.info("Whisper transcription produced text")
                    await MainActor.run {
                        self.counter.processWhisperTranscript(cleaned)
                    }
                }
            } catch {
                logger.error("Transcription error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
