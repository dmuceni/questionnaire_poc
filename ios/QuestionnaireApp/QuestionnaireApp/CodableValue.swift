import Foundation

/// Rappresenta un valore dinamico proveniente dal backend (stringa o numero).
/// Serve per gestire indifferentemente le risposte salvate dall'utente.
enum CodableValue: Hashable {
    case string(String)
    case int(Int)
}

extension CodableValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                CodableValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Valore non supportato")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

extension CodableValue {
    var stringKey: String {
        switch self {
        case .int(let value):
            return String(value)
        case .string(let value):
            return value
        }
    }
}
