import Foundation

enum AppConfiguration {
    /// Base URL del backend Node.js/Express che alimenta anche il frontend web.
    ///
    /// L'URL può essere sovrascritto impostando la variabile d'ambiente `API_BASE_URL`
    /// (nelle scheme di Xcode) oppure il valore `APIBaseURL` all'interno dell'`Info.plist`.
    /// In assenza di override viene usato `http://localhost:3001`, con fallback a `http://192.168.0.246:3001`.
    static let baseURL: URL = {
        if let envValue = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: envValue), !envValue.isEmpty {
            return url
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           let url = URL(string: plistValue), !plistValue.isEmpty {
            return url
        }

        return URL(string: "http://localhost:3001")!
    }()
    
    static let fallbackURL = URL(string: "http://192.168.0.246:3001")!

    static let userID = "user_123"
}
