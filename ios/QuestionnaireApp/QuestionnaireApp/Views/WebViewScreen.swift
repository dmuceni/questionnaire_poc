import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit

// Store per esporre l'istanza WKWebView a SwiftUI
final class WebViewStore: ObservableObject {
    @Published var webView: WKWebView? = nil
}

struct WebViewScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var store = WebViewStore()
    let url: URL
    var backSelectors: [String]? = nil

    @State private var lastJSResult: String? = nil
    @State private var showNoBackAlert: Bool = false
    @State private var showJSResultAlert: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                WebView(url: url, store: store)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { triggerPageBack() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Indietro")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Test Back") { runTestBackJS() }
                        Button("Chiudi") { presentationMode.wrappedValue.dismiss() }
                    }
                }
            }
            .alert(isPresented: $showNoBackAlert) {
                Alert(title: Text("Nessuna navigazione indietro disponibile"), message: Text("Non è stato possibile eseguire il comportamento di indietro nella pagina. Verrà chiesto all'utente di tornare manualmente."), dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showJSResultAlert) {
                Alert(title: Text("Test Back result"), message: Text(lastJSResult ?? "(nessun risultato)"), dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func runTestBackJS() {
        triggerPageBack(testOnly: true)
    }

    private func triggerPageBack(testOnly: Bool = false) {
        guard let webView = store.webView else {
            showNoBackAlert = true
            return
        }
        let selectors = (backSelectors?.isEmpty == false) ? backSelectors! : ["button.back", ".back-button", "#back", "a[rel=back]"]
        let selectorsArrayString = selectors.map { "'\($0)'" }.joined(separator: ",")
        let js = "(function(){\n  try{\n    var sels=[\(selectorsArrayString)];\n    for(var i=0;i<sels.length;i++){\n      var el=document.querySelector(sels[i]);\n      if(el){ el.click(); return 'clicked:'+sels[i]; }\n    }\n    if(window.customBack){ try{ window.customBack(); return 'customBack'; } catch(e) { /* continue */ } }\n    if(window.history && window.history.length>1){ window.history.back(); return 'history.back'; }\n    return 'no-op';\n  } catch(e) { return 'error:'+e.toString(); }\n})()"
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                self.lastJSResult = "error: \(error.localizedDescription)"
                self.showJSResultAlert = true
                return
            }
            if let res = result as? String {
                self.lastJSResult = res
                if testOnly {
                    self.showJSResultAlert = true
                    return
                }
                if res.hasPrefix("no-op") || res.hasPrefix("error") {
                    self.showNoBackAlert = true
                    return
                }
            } else {
                self.lastJSResult = "(no string result)"
                self.showJSResultAlert = true
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var store: WebViewStore

    init(url: URL, store: WebViewStore) {
        self.url = url
        self.store = store
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wk = WKWebView(frame: .zero, configuration: config)
        wk.navigationDelegate = context.coordinator
        wk.allowsBackForwardNavigationGestures = true
        wk.load(URLRequest(url: url))
        DispatchQueue.main.async {
            self.store.webView = wk
        }
        return wk
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // no-op
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        init(_ parent: WebView) { self.parent = parent }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Notifica di completamento navigazione
        }
    }
}

#else

// Non-UIKit stubs to avoid analyzer/type errors when this file is parsed for other platforms
final class WebViewStore: ObservableObject { @Published var webView: Any? = nil }

struct WebViewScreen: View {
    let url: URL
    var backSelectors: [String]? = nil
    var body: some View { Text("WebView non disponibile su questa piattaforma") }
}

struct WebView: View {
    let url: URL
    var body: some View { EmptyView() }
}

#endif
