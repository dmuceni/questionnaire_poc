import Foundation

enum QuestionType: String, Codable {
    case rating
    case card
    case open
}

struct QuestionOption: Codable, Hashable, Identifiable {
    let id: String
    let label: String
}

enum QuestionNext: Codable, Hashable {
    case id(String)
    case mapping([String: String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .id(stringValue)
        } else if let dict = try? container.decode([String: String].self) {
            self = .mapping(dict)
        } else if let intValue = try? container.decode(Int.self) {
            self = .id(String(intValue))
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Formato next non supportato")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .id(let value):
            try container.encode(value)
        case .mapping(let dict):
            try container.encode(dict)
        }
    }
}

struct Question: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let type: QuestionType
    let scale: Int?
    let options: [QuestionOption]?
    let next: QuestionNext?
}

// MARK: - Page Models
struct QuestionnairePage: Codable, Identifiable {
    let id: String
    let title: String
    let questions: [Question]
    let showContinue: Bool
    let isLast: Bool
}

struct PagedQuestionnaireResponse: Codable {
    let pages: [QuestionnairePage]
}

struct UserPageAnswersResponse: Codable {
    let pageAnswers: [String: [String: CodableValue]]
}
