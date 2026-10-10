// ViewModel.swift

import Foundation
import Combine

@MainActor
final class ViewModel: ObservableObject {
    
    // MARK: - Public State
    
    @Published var userInput: String = ""
    @Published var isLoading: Bool = false
    @Published var isPlaybackFinished: Bool = false
    @Published var responseText: String
    @Published var isAwaitingConfirmation: Bool = false
    @Published var pendingPrompt: String = ""
    @Published var hasResponse: Bool = false
    
    let dismissKeyboard = PassthroughSubject<Void, Never>()
    
    var shouldShowBottomArea: Bool {
        isAwaitingConfirmation || (hasResponse && !isPlaybackFinished)
    }
    
    // MARK: - Private State
    
    private let voiceManager = VoiceOutputManager()
    private var previousInput: String = ""
    private var pendingWorkItem: DispatchWorkItem?
    private let initialMessage = "La risposta di \(GPTService.modelName) apparirà qui"
    
    // MARK: - Initialization

    init() {
        self.responseText = initialMessage
    }
    
    // MARK: - API (Send Message)
    
    func sendMessage(prompt: String) {
        
        isPlaybackFinished = false
        responseText = "Generazione in corso…"
        hasResponse = true
        isLoading = true
        
        Task {
            defer { isLoading = false }
            
            do {
                let fullText = try await GPTService.complete(
                    prompt: prompt,
                    apiKey: Secrets.openAIKey
                )
                
                let wordCount = fullText.split { $0.isWhitespace }.count
                let header = "Questa risposta contiene \(wordCount) parole.\n\n"
                responseText = header + fullText
                
                let chunks = splitForVoice(responseText)
                voiceManager.prepare(chunks)

                if voiceManager.hasNextChunk {
                    voiceManager.speakNext()
                } else {
                    isPlaybackFinished = true
                }
            } catch {
                responseText = "Errore durante la generazione: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Voice Playback
    
    func readNextChunk() {
        if voiceManager.hasNextChunk {
            voiceManager.speakNext()
            
            if !voiceManager.hasNextChunk {
                isPlaybackFinished = true
            }
        } else {
            isPlaybackFinished = true
        }
    }
    
    func replayLastChunk() {
        voiceManager.replayLast()
    }
    
    // MARK: - User Actions
    
    func submit() {
        let cleanPrompt = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return }

        pendingPrompt = cleanPrompt
        isAwaitingConfirmation = true
        
        dismissKeyboard.send()
        
        voiceManager.speakImmediate(
            "Il prompt è il seguente: \(pendingPrompt). Per inviare premi Conferma, oppure fai un tap breve. Per annullare fai un tap lungo."
        )
    }
    
    func confirmSend() {
        isAwaitingConfirmation = false
        let prompt = pendingPrompt
        pendingPrompt = ""
        previousInput = ""
        voiceManager.speakImmediate("Invio")
        sendMessage(prompt: prompt)
    }

    func cancelSend() {
        isAwaitingConfirmation = false
        hasResponse = false
        pendingPrompt = ""
        userInput = ""
        previousInput = ""
        responseText = initialMessage
        // dismissKeyboard.send()
        voiceManager.speakImmediate("Annullato")
    }
    
    // MARK: - Typing Feedback
    
    func handleTypingChange(newValue: String) {
        
        if previousInput.hasSuffix("\n") && newValue.hasSuffix("\n") {
            previousInput = ""
            pendingWorkItem?.cancel()
            submit()
            return
        }
        
        defer {
            previousInput = newValue
        }
        
        if newValue.count < previousInput.count {
            
            pendingWorkItem?.cancel()
            
            let oldWords = previousInput.split { $0.isWhitespace }
            let newWords = newValue.split { $0.isWhitespace }
            
            if newWords.count < oldWords.count {
                voiceManager.speakImmediate("Parola cancellata")
            } else {
                voiceManager.speakImmediate("Back")
            }
            
            return
        }
        
        guard let lastChar = newValue.last else { return }
        
        if lastChar != " " && lastChar != "\n" {
            pendingWorkItem?.cancel()
            voiceManager.speakImmediate(String(lastChar))
            return
        }
        
        if lastChar == "\n" {
            pendingWorkItem?.cancel()
            voiceManager.speakImmediate("A capo")
            return
        }
        
        if lastChar == " " {
            
            pendingWorkItem?.cancel()
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                let words = self.userInput
                    .trimmingCharacters(in: .whitespaces)
                    .split(separator: " ")
                
                if let lastWord = words.last {
                    self.voiceManager.speakImmediate(String(lastWord))
                }
            }
            
            pendingWorkItem = workItem
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
            
            return
        }
    }
    
    // MARK: - Text Processing
    
    private func splitForVoice(_ text: String) -> [String] {
        
        let punctuation = CharacterSet(charactersIn: ".,;:!?")
        
        let pauseWords: Set<String> = [ /* "but", "how", "because", "before", "after", "when", "while", "where", "from" */ ]
        
        var chunks: [String] = []
        
        let paragraphs = text.components(separatedBy: "\n")
        
        for paragraph in paragraphs {
            
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespaces)
            if trimmedParagraph.isEmpty { continue }
            
            var current = ""
            let words = trimmedParagraph.split(separator: " ", omittingEmptySubsequences: false)
            
            for word in words {
                let wordString = String(word)
                let lowerWord = wordString.lowercased()
                
                if pauseWords.contains(lowerWord),
                   !current.trimmingCharacters(in: .whitespaces).isEmpty {
                    
                    chunks.append(current.trimmingCharacters(in: .whitespaces))
                    current = wordString + " "
                    continue
                }
                
                current += wordString + " "
                
                if wordString.rangeOfCharacter(from: punctuation) != nil {
                    chunks.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                }
            }
            
            if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                chunks.append(current.trimmingCharacters(in: .whitespaces))
            }
        }
        
        return chunks
    }
}
