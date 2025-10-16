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
            print("🔧 AppConfiguration: Using API_BASE_URL env variable -> \(url)")
            return url
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           let url = URL(string: plistValue), !plistValue.isEmpty {
            print("🔧 AppConfiguration: Using Info.plist APIBaseURL -> \(url)")
            return url
        }

        let fallback = URL(string: "http://192.168.0.246:3001")!
        print("🔧 AppConfiguration: Falling back to hardcoded IP -> \(fallback)")
        return fallback
    }()
    
    static let fallbackURL = URL(string: "http://192.168.0.246:3001")!

    static let userID = "user_123"
}
