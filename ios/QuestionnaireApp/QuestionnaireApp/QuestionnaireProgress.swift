import Foundation

struct QuestionnaireProgress: Codable, Identifiable, Hashable {
    let cluster: String
    let title: String
    let percent: Int

    var id: String { cluster }
}

struct UserAnswersResponse: Codable {
    let answers: [String: CodableValue]
}
