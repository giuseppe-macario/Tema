// GPTService.swift

import Foundation

struct GPTService {
    
    // MARK: - Config
    
    enum Config {
        static let url = URL(string: "https://api.openai.com/v1/responses")!
        static let model = "gpt-5.4-mini"
        static let systemPrompt = "Scrivi una trattazione tecnica completa e argomentata. Inquadra il problema in modo chiaro. Spiega i principi teorici coinvolti. Descrivi i concetti fondamentali e le relazioni tra essi. Mantieni un discorso continuo e ben collegato. Evita ripetizioni e generalizzazioni vaghe. Usa un linguaggio tecnico preciso ma comprensibile. Usa frasi molto brevi e con virgole. Non usare formule, calcoli o passaggi numerici. Non usare parentesi, trattini, liste o elenchi, ma ricordati di inserire gli apostrofi dove necessario. Struttura il tema in questo modo: introduzione, svolgimento, conclusione. Il prompt può contenere errori di battitura: ignorali e comprendi l'intento dell'utente."
    }
    
    static var modelName: String {
        Config.model
    }
    
    // MARK: - Public API
    
    static func complete(prompt: String, apiKey: String) async throws -> String {
        
        let body = Request(
            model: Config.model,
            input: [
                .system(Config.systemPrompt),
                .user(prompt)
            ]
        )
        
        var request = URLRequest(url: Config.url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // MARK: - Quick error handling
        
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode(APIError.self, from: data))?.error.message
            throw NSError(domain: "GPTService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: message ?? "Request failed"
            ])
        }
        
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        
        let text = decoded.output
            .flatMap { $0.content ?? [] }
            .compactMap { $0.text }
            .joined()
        
        return text.isEmpty ? "Nessuna risposta ricevuta." : text
    }
}

// MARK: - Request Models

private struct Request: Encodable {
    let model: String
    let input: [Message]
    
    struct Message: Encodable {
        let role: Role
        let content: [Content]
        
        static func system(_ text: String) -> Self {
            .init(role: .system, content: [.text(text)])
        }
        
        static func user(_ text: String) -> Self {
            .init(role: .user, content: [.text(text)])
        }
    }
    
    struct Content: Encodable {
        let type: ContentType
        let text: String
        
        static func text(_ value: String) -> Self {
            .init(type: .inputText, text: value)
        }
    }
    
    enum Role: String, Encodable {
        case system
        case user
    }
    
    enum ContentType: String, Encodable {
        case inputText = "input_text"
    }
}

// MARK: - Response Models

private struct Response: Decodable {
    let output: [Output]
    
    struct Output: Decodable {
        let content: [Content]?
    }
    
    struct Content: Decodable {
        let type: String
        let text: String?
    }
}

// MARK: - API Error

private struct APIError: Decodable {
    let error: Detail
    
    struct Detail: Decodable {
        let message: String
    }
}
