import Foundation

enum AppConfiguration {
    /// Base URL del backend Node.js/Express che alimenta anche il frontend web.
    static let baseURL = URL(string: "http://localhost:3001")!
    static let userID = "user_123"
}
