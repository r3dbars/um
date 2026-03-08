import AVFoundation
import Combine
import SwiftWhisper
import os

private let logger = Logger(subsystem: "com.um.app", category: "WhisperManager")

/// Manages audio capture and whisper.cpp transcription for filler word detection.
/// Replaces SFSpeechRecognizer with local Whisper model for verbatim transcription
/// that preserves filler words like "um", "uh", etc.
class WhisperManager: NSObject, ObservableObject {
    static let shared = WhisperManager()

    @Published var isListening = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let counter = FillerWordCounter.shared
    private var whisper: Whisper?

    /// Audio buffer accumulator — we collect chunks then transcribe
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16000  // Whisper expects 16kHz mono
    private var transcribeTimer: Timer?

    /// How often to transcribe accumulated audio (seconds)
    private let transcribeInterval: TimeInterval = 3.0

    override init() {
        super.init()
        loadModel()
    }

    // MARK: - Model Loading

    private func loadModel() {
        let modelName = "ggml-base.en.bin"

        // Check several locations for the model file
        let searchPaths: [URL] = [
            // Next to the binary (development)
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("models/\(modelName)"),
            // App Support directory
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Um/\(modelName)"),
            // Home directory models folder
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("models/\(modelName)"),
        ]

        var modelURL: URL?
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                modelURL = path
                logger.info("Found model at: \(path.path, privacy: .public)")
                break
            }
        }

        guard let url = modelURL else {
            let searched = searchPaths.map(\.path).joined(separator: "\n  ")
            logger.error("Model not found. Searched:\n  \(searched, privacy: .public)")
            DispatchQueue.main.async {
                self.errorMessage = "Whisper model not found. Place \(modelName) in the models/ directory."
            }
            return
        }

        let params = WhisperParams(strategy: .greedy)
        params.language = .english
        params.no_context = true
        whisper = Whisper(fromFileURL: url, withParams: params)
        logger.info("Whisper model loaded successfully")
    }

    // MARK: - Start / Stop

    func startListening() {
        guard whisper != nil else {
            logger.error("Cannot start — Whisper model not loaded")
            return
        }
        guard !audioEngine.isRunning else {
            logger.debug("Audio engine already running")
            return
        }

        logger.info("Starting audio capture for Whisper transcription")

        do {
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            logger.info("Input format: sampleRate=\(inputFormat.sampleRate), channels=\(inputFormat.channelCount)")

            // Convert to 16kHz mono for Whisper
            guard let convertFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                     sampleRate: sampleRate,
                                                     channels: 1,
                                                     interleaved: false) else {
                logger.error("Failed to create conversion format")
                return
            }

            guard let converter = AVAudioConverter(from: inputFormat, to: convertFormat) else {
                logger.error("Failed to create audio converter")
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self else { return }
                self.convertAndAppend(buffer: buffer, converter: converter, outputFormat: convertFormat)
            }

            audioEngine.prepare()
            try audioEngine.start()

            audioBuffer.removeAll()

            // Periodically transcribe accumulated audio
            transcribeTimer = Timer.scheduledTimer(withTimeInterval: transcribeInterval, repeats: true) { [weak self] _ in
                self?.transcribeBuffer()
            }

            DispatchQueue.main.async {
                self.isListening = true
                self.errorMessage = nil
                self.counter.startSession()
                logger.info("Whisper listening started")
            }
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Mic error: \(error.localizedDescription)"
            }
        }
    }

    func stopListening() {
        transcribeTimer?.invalidate()
        transcribeTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Transcribe any remaining audio
        transcribeBuffer()

        audioBuffer.removeAll()
        DispatchQueue.main.async {
            self.isListening = false
            self.counter.stopSession()
            logger.info("Whisper listening stopped")
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
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                                      frameCapacity: frameCount) else { return }

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
        let samples = Array(UnsafeBufferPointer(start: floatData[0],
                                                 count: Int(convertedBuffer.frameLength)))
        audioBuffer.append(contentsOf: samples)
    }

    // MARK: - Transcription

    private func transcribeBuffer() {
        guard let whisper else { return }
        let samples = audioBuffer
        audioBuffer.removeAll()

        // Need at least 0.5s of audio to be worth transcribing
        guard samples.count > Int(sampleRate * 0.5) else { return }

        // Don't overlap with an in-progress transcription
        guard whisper.inProgress == false else { return }

        let duration = Double(samples.count) / sampleRate
        logger.info("Transcribing \(String(format: "%.1f", duration), privacy: .public)s of audio (\(samples.count) samples)")

        Task {
            do {
                let segments = try await whisper.transcribe(audioFrames: samples)
                let transcript = segments.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)

                // Filter Whisper hallucinations on silence/noise
                var cleaned = transcript
                    .replacingOccurrences(of: "[BLANK_AUDIO]", with: "")
                    .replacingOccurrences(of: "(silence)", with: "")
                // Remove parenthesized/bracketed hallucinations like "(birds chirp)"
                if let regex = try? NSRegularExpression(pattern: "\\([^)]*\\)|\\[[^\\]]*\\]") {
                    cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
                }
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

                if !cleaned.isEmpty {
                    let transcript = cleaned
                    logger.info("Whisper transcript: \"\(transcript, privacy: .public)\"")
                    await MainActor.run {
                        self.counter.processWhisperTranscript(transcript)
                    }
                } else {
                    logger.debug("Empty/silent chunk")
                }
            } catch {
                logger.error("Transcription error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
