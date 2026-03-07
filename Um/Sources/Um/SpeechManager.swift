import Speech
import AVFoundation
import Combine

class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()

    @Published var isListening = false
    @Published var authStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let counter = FillerWordCounter.shared

    /// Keep the audio engine running across restarts to eliminate the gap
    private var isRestarting = false

    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        recognizer?.delegate = self
        authStatus = SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Auth

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authStatus = status
                completion(status == .authorized)
            }
        }
    }

    // MARK: - Start / Stop

    func startListening() {
        guard authStatus == .authorized else {
            requestPermissions { [weak self] granted in
                if granted { self?.startListening() }
            }
            return
        }

        guard !audioEngine.isRunning else { return }

        do {
            try beginRecognition()
            DispatchQueue.main.async {
                self.isListening = true
                self.errorMessage = nil
                self.counter.startSession()
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Mic error: \(error.localizedDescription)"
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        DispatchQueue.main.async {
            self.isListening = false
            self.counter.stopSession()
        }
    }

    // MARK: - Recognition Engine

    private func beginRecognition() throws {
        // Tear down any previous recognition task (but keep audio engine if restarting)
        if !isRestarting {
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }
        }
        task?.cancel()
        task = nil

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { throw RecognitionError.requestCreationFailed }

        request.shouldReportPartialResults = true
        // On-device only — no audio leaves the Mac
        if #available(macOS 13.0, *) {
            request.requiresOnDeviceRecognition = true
        }

        if !isRestarting {
            let inputNode = audioEngine.inputNode
            let fmt = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.counter.processTranscript(transcript)
                }
                // SFSpeechRecognizer resets after ~60s of audio
                // When it does, isFinal fires and we restart seamlessly
                if result.isFinal {
                    DispatchQueue.main.async {
                        self.counter.resetTranscriptTracking()
                    }
                    self.restartRecognition()
                }
            }

            if let error {
                let ns = error as NSError
                // Ignore benign cancellation codes
                let benign = [203, 216, 301]
                if !benign.contains(ns.code) {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func restartRecognition() {
        guard isListening else { return }
        // Keep audio engine running — only restart the recognition task
        // This eliminates the gap where words could be missed
        isRestarting = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isListening else { return }
            self.task?.cancel()
            self.task = nil
            self.request?.endAudio()

            // Create new request that reuses the existing audio tap
            self.request = SFSpeechAudioBufferRecognitionRequest()
            guard let request = self.request else {
                self.isRestarting = false
                return
            }
            request.shouldReportPartialResults = true
            if #available(macOS 13.0, *) {
                request.requiresOnDeviceRecognition = true
            }

            self.task = self.recognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let result {
                    let transcript = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.counter.processTranscript(transcript)
                    }
                    if result.isFinal {
                        DispatchQueue.main.async {
                            self.counter.resetTranscriptTracking()
                        }
                        self.restartRecognition()
                    }
                }

                if let error {
                    let ns = error as NSError
                    let benign = [203, 216, 301]
                    if !benign.contains(ns.code) {
                        DispatchQueue.main.async {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            self.isRestarting = false
        }
    }

    // MARK: - Errors

    enum RecognitionError: LocalizedError {
        case requestCreationFailed
        var errorDescription: String? { "Failed to create speech recognition request." }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                          availabilityDidChange available: Bool) {
        if !available && isListening {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognition became unavailable."
                self.stopListening()
            }
        }
    }
}
