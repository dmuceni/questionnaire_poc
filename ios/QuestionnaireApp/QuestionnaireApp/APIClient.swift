import Foundation

actor APIClient {
    static let shared = APIClient()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder = JSONEncoder()
    private var currentBaseURL: URL = AppConfiguration.baseURL

    func fetchProgress() async throws -> [QuestionnaireProgress] {
        try await request(path: "/api/progress/\(AppConfiguration.userID)")
    }

    func fetchQuestionnaire(cluster: String) async throws -> [Question] {
        try await request(path: "/api/questionnaire/\(cluster)")
    }
    
    func fetchPages(cluster: String) async throws -> PagedQuestionnaireResponse {
        try await request(path: "/api/pages/\(cluster)")
    }

    func fetchUserAnswers(cluster: String) async throws -> [String: CodableValue] {
        let response: UserAnswersResponse = try await request(path: "/api/userAnswers/\(AppConfiguration.userID)/\(cluster)")
        return response.answers
    }
    
    func fetchPageAnswers(cluster: String) async throws -> [String: [String: CodableValue]] {
        let response: UserPageAnswersResponse = try await request(path: "/api/pageAnswers/\(AppConfiguration.userID)/\(cluster)")
        return response.pageAnswers
    }
    
    func fetchPageAnswers(cluster: String, pageId: String) async throws -> [String: CodableValue] {
        let response: UserAnswersResponse = try await request(path: "/api/pageAnswers/\(AppConfiguration.userID)/\(cluster)/\(pageId)")
        return response.answers
    }

    func saveAnswers(_ answers: [String: CodableValue], cluster: String) async {
        let body = UserAnswersResponse(answers: answers)
        do {
            try await send(path: "/api/userAnswers/\(AppConfiguration.userID)/\(cluster)", method: "POST", body: body)
        } catch {
            print("❌ Errore salvataggio risposte:", error)
        }
    }
    
    func savePageAnswers(_ answers: [String: CodableValue], cluster: String, pageId: String) async {
        let body = UserAnswersResponse(answers: answers)
        do {
            try await send(path: "/api/pageAnswers/\(AppConfiguration.userID)/\(cluster)/\(pageId)", method: "POST", body: body)
        } catch {
            print("❌ Errore salvataggio risposte pagina:", error)
        }
    }

    func resetAnswers(cluster: String) async throws {
        let request = try makeURLRequest(path: "/api/userAnswers/\(AppConfiguration.userID)/reset/\(cluster)", method: "POST")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func resetPageAnswers(cluster: String) async throws {
        let request = try makeURLRequest(path: "/api/pageAnswers/\(AppConfiguration.userID)/\(cluster)/reset", method: "POST")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Private

    private func request<T: Decodable>(path: String) async throws -> T {
        do {
            let request = try makeURLRequest(path: path)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return try decoder.decode(T.self, from: data)
        } catch {
            // Se il primo tentativo fallisce e stiamo usando localhost, prova con l'IP fallback
            if currentBaseURL == AppConfiguration.baseURL && AppConfiguration.baseURL.host == "localhost" {
                print("🔄 Tentativo fallback con IP \(AppConfiguration.fallbackURL.absoluteString)")
                currentBaseURL = AppConfiguration.fallbackURL
                
                let request = try makeURLRequest(path: path)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return try decoder.decode(T.self, from: data)
            } else {
                throw error
            }
        }
    }

    private func send<T: Encodable>(path: String, method: String, body: T) async throws {
        do {
            var request = try makeURLRequest(path: path, method: method)
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
        } catch {
            // Se il primo tentativo fallisce e stiamo usando localhost, prova con l'IP fallback
            if currentBaseURL == AppConfiguration.baseURL && AppConfiguration.baseURL.host == "localhost" {
                print("🔄 Tentativo fallback con IP \(AppConfiguration.fallbackURL.absoluteString)")
                currentBaseURL = AppConfiguration.fallbackURL
                
                var request = try makeURLRequest(path: path, method: method)
                request.httpBody = try encoder.encode(body)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
            } else {
                throw error
            }
        }
    }

    private func makeURLRequest(path: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: currentBaseURL) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }
}
