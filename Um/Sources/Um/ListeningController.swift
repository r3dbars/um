import Combine
import Foundation

/// Single facade the UI talks to. Prefers on-device Whisper (verbatim fillers)
/// and falls back to Apple Speech if the model file is missing.
///
/// Session start/stop lives here once: engines only start and stop capture.
final class ListeningController: ObservableObject {
    static let shared = ListeningController()

    enum Engine: String {
        case whisper
        case appleSpeech
    }

    @Published var isListening = false
    @Published var errorMessage: String?
    @Published private(set) var engine: Engine = .whisper

    private let whisper = WhisperManager.shared
    private let speech = SpeechManager.shared
    private let counter = FillerWordCounter.shared
    private var cancellables = Set<AnyCancellable>()
    private var userWantsListening = false

    var usesWhisper: Bool { engine == .whisper }

    var statusText: String {
        if let errorMessage, !errorMessage.isEmpty { return errorMessage }
        if isListening { return "Listening" }
        return "Not listening"
    }

    init() {
        engine = whisper.isModelAvailable ? .whisper : .appleSpeech
        bind()
    }

    func startListening() {
        userWantsListening = true
        engine = whisper.isModelAvailable ? .whisper : .appleSpeech
        if engine == .whisper {
            speech.stopCapture()
            whisper.startListening()
        } else {
            whisper.stopCapture()
            speech.startListening()
        }
    }

    func stopListening() {
        userWantsListening = false
        whisper.stopCapture()
        speech.stopCapture()
        counter.stopSession()
    }

    private func bind() {
        whisper.$isListening
            .combineLatest(speech.$isListening)
            .receive(on: RunLoop.main)
            .sink { [weak self] whisperOn, speechOn in
                guard let self else { return }
                self.isListening = self.userWantsListening && (whisperOn || speechOn)
                if self.userWantsListening && (whisperOn || speechOn) {
                    self.counter.startSession()
                }
            }
            .store(in: &cancellables)

        whisper.$errorMessage
            .combineLatest(speech.$errorMessage)
            .receive(on: RunLoop.main)
            .sink { [weak self] whisperError, speechError in
                guard let self else { return }
                if self.engine == .whisper {
                    self.errorMessage = whisperError
                } else {
                    self.errorMessage = speechError
                }
            }
            .store(in: &cancellables)

        whisper.$isModelAvailable
            .receive(on: RunLoop.main)
            .sink { [weak self] available in
                guard let self, !self.isListening else { return }
                self.engine = available ? .whisper : .appleSpeech
            }
            .store(in: &cancellables)
    }
}
