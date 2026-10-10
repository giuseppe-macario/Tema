// VoiceOutputManager.swift

import AVFoundation

final class VoiceOutputManager {
    
    // MARK: - Properties
    
    private enum Config {
        static let language = "it-IT"
        static let voiceIdentifier = "com.apple.voice.premium.it-IT.Federica"
        static let rate: Float = 0.10
        static let volume: Float = 0.12
    }
    
    private var chunks: [String] = []
    private var currentIndex: Int = 0
    
    private let synthesizer = AVSpeechSynthesizer()
    
    var hasNextChunk: Bool {
        currentIndex < chunks.count
    }
    
    // MARK: - Initialization
    
    init() {
        configureAudioSession()
        
        // DEBUG: stampa l'elenco delle voci disponibili (identifier + language)
        // for voice in AVSpeechSynthesisVoice.speechVoices() {
        //     print(voice.identifier, "-", voice.language)
        // }
    }
    
    // MARK: - Public API
    
    // Prepara i blocchi da leggere (reset completo)
    func prepare(_ newChunks: [String]) {
        chunks = newChunks
        currentIndex = 0
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    // Legge il prossimo blocco
    func speakNext() {
        synthesizer.stopSpeaking(at: .immediate)

        guard currentIndex < chunks.count else { return }

        synthesizer.speak(makeUtterance(text: chunks[currentIndex]))
        currentIndex += 1
    }
    
    // Rilegge l'ultimo blocco letto
    func replayLast() {
        guard currentIndex > 0 else { return }
        
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(makeUtterance(text: chunks[currentIndex - 1]))
    }
    
    func speakImmediate(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(makeUtterance(text: text))
    }
    
    // MARK: - Private Methods
    
    private func makeUtterance(text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)

        if let voice = AVSpeechSynthesisVoice(identifier: Config.voiceIdentifier) {
            utterance.voice = voice
        } else if let fallback = AVSpeechSynthesisVoice(language: Config.language) {
            utterance.voice = fallback
        }

        utterance.rate = Config.rate
        utterance.volume = Config.volume

        return utterance
    }
    
    // MARK: - Audio Configuration
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)
    }
}
