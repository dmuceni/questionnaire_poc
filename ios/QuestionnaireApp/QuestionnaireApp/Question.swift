import Foundation

enum QuestionType: String, Codable {
    case rating
    case card
    case open
    case multipleChoice = "multiple_choice"
    case multipleChoiceGrouped = "multiple_choice_grouped" // nuovo tipo con tabs/gruppi e ricerca
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
    let required: Bool?
    // Nuovi campi opzionali per domande grouped
    let groups: [QuestionGroup]?
    let searchEnabled: Bool?
    let maxSelections: Int? // limite massimo selezioni per multiple choice grouped
    
    // Computed property to safely get required value with default
    var isRequired: Bool {
        return required ?? false
    }

    init(id: String,
         text: String,
         type: QuestionType,
         scale: Int? = nil,
         options: [QuestionOption]? = nil,
         next: QuestionNext? = nil,
         required: Bool? = nil,
         groups: [QuestionGroup]? = nil,
         searchEnabled: Bool? = nil,
         maxSelections: Int? = nil) {
        self.id = id
        self.text = text
        self.type = type
        self.scale = scale
        self.options = options
        self.next = next
        self.required = required
        self.groups = groups
        self.searchEnabled = searchEnabled
        self.maxSelections = maxSelections
    }
}

// Rappresenta un gruppo/tab di opzioni (es. Serie A/B/C)
struct QuestionGroup: Codable, Hashable, Identifiable {
    let id: String // es: "serie_a"
    let label: String // es: "Serie A"
    let options: [QuestionOption]
}

// MARK: - Page Models
struct QuestionnairePage: Codable, Identifiable {
    let id: String
    let title: String? // reso opzionale: mostra solo se presente
    let description: String? // aggiunto se non esisteva già
    let questions: [Question]
    let showContinue: Bool
    let isLast: Bool
    let conditionalRouting: ConditionalRouting?
}

struct ConditionalRouting: Codable {
    let rules: [RoutingRule]
    let defaultAction: String // "complete" or next page id
}

struct RoutingRule: Codable {
    let condition: RoutingCondition
    let nextPage: String
    let priority: Int
}

struct RoutingCondition: Codable {
    let questionId: String
    let operatorType: String // ">=", ">", "==", "<", "<="
    let value: String // Ora usiamo sempre stringa per flessibilità
    
    enum CodingKeys: String, CodingKey {
        case questionId
        case operatorType = "operator"
        case value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        questionId = try container.decode(String.self, forKey: .questionId)
        operatorType = try container.decode(String.self, forKey: .operatorType)
        
        // Decodifica del valore con gestione robusta dei tipi
        do {
            // Prova prima a decodificare come String
            value = try container.decode(String.self, forKey: .value)
        } catch {
            do {
                // Se fallisce, prova come Double
                let doubleValue = try container.decode(Double.self, forKey: .value)
                value = String(doubleValue)
            } catch {
                do {
                    // Se fallisce, prova come Int
                    let intValue = try container.decode(Int.self, forKey: .value)
                    value = String(intValue)
                } catch {
                    // Se tutto fallisce, lanciamo un errore personalizzato
                    print("🔍 DEBUG: Failed to decode value for condition. Error: \(error)")
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Il valore deve essere una stringa, un numero o un intero. Error: \(error)"
                        )
                    )
                }
            }
        }
    }
    
    // Funzione helper per convertire in Double quando necessario
    var doubleValue: Double? {
        return Double(value)
    }
}

struct PagedQuestionnaireResponse: Codable {
    let pages: [QuestionnairePage]
}

struct UserPageAnswersResponse: Codable {
    let pageAnswers: [String: [String: CodableValue]]
}
