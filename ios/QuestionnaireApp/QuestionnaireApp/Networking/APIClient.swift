import Foundation

actor APIClient {
    static let shared = APIClient()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder = JSONEncoder()

    func fetchProgress() async throws -> [QuestionnaireProgress] {
        try await request(path: "/api/progress/\(AppConfiguration.userID)")
    }

    func fetchQuestionnaire(cluster: String) async throws -> [Question] {
        try await request(path: "/api/questionnaire/\(cluster)")
    }

    func fetchUserAnswers(cluster: String) async throws -> [String: CodableValue] {
        let response: UserAnswersResponse = try await request(path: "/api/userAnswers/\(AppConfiguration.userID)/\(cluster)")
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

    func resetAnswers(cluster: String) async throws {
        let request = try makeURLRequest(path: "/api/userAnswers/\(AppConfiguration.userID)/reset/\(cluster)", method: "POST")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Private

    private func request<T: Decodable>(path: String) async throws -> T {
        let request = try makeURLRequest(path: path)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func send<T: Encodable>(path: String, method: String, body: T) async throws {
        var request = try makeURLRequest(path: path, method: method)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func makeURLRequest(path: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: AppConfiguration.baseURL) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }
}
