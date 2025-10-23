import SwiftUI

/// Wrapper minimo che riusa `WebViewScreen` per evitare duplicati.
public struct WebViewModal: View {
    public let url: URL
    public var backSelectors: [String]? = nil

    public init(url: URL, backSelectors: [String]? = nil) {
        self.url = url
        self.backSelectors = backSelectors
    }

    public var body: some View {
        WebViewScreen(url: url, backSelectors: backSelectors)
    }
}
