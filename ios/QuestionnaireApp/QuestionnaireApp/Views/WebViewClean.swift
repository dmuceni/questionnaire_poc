import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit

final class WebViewCleanStore: ObservableObject {
    @Published var webView: WKWebView? = nil
}


struct WebViewCleanModal: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var store = WebViewCleanStore()
    let url: URL
    var title: String = "Questionario"
    /// Callback chiamato quando l'utente tocca lo chevron sinistro. Deve eseguire lo "step indietro" dell'app.
    var onBack: (() -> Void)? = nil

    init(url: URL, title: String = "Questionario", onBack: (() -> Void)? = nil) {
        self.url = url
        self.title = title
        self.onBack = onBack
    }

    @State private var lastJSResult: String? = nil
    @State private var showNoBackAlert: Bool = false
    @State private var showJSResultAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar controllata dall'app
            WebViewClean(url: url, store: store)
                .edgesIgnoringSafeArea(.bottom)
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            Button(action: {
                                print("🔔 WebViewClean: chevron tapped, onBackProvided=\(onBack != nil)")
                                if let onBack = onBack {
                                    onBack()
                                } else {
                                    // Post a global notification so other parts of the app
                                    // (e.g. QuestionnairePageFlowView) can observe it and
                                    // transform it into a page-step-back.
                                    NotificationCenter.default.post(name: Notification.Name("WebViewChevronBackTapped"), object: nil)
                                    triggerPageBack()
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            Text(title)
                                .font(.headline)
                                .lineLimit(1)

                            Spacer()

                            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.systemBackground))
                        Divider()
                    }
                }
        }
        .alert(isPresented: $showNoBackAlert) {
            Alert(title: Text("Nessuna navigazione indietro disponibile"), message: Text("Non è stato possibile eseguire il comportamento di indietro nella pagina."), dismissButton: .default(Text("OK")))
        }
        .alert(isPresented: $showJSResultAlert) {
            Alert(title: Text("Test Back result"), message: Text(lastJSResult ?? "(nessun risultato)"), dismissButton: .default(Text("OK")))
        }
    }

    private func triggerPageBack(testOnly: Bool = false) {
        guard let webView = store.webView else { self.showNoBackAlert = true; return }
        let selectors = ["button.back", ".back-button", "#back", "a[rel=back]"]
        let selectorsArrayString = selectors.map { "'\($0)'" }.joined(separator: ",")
        let js = "(function(){\n  try{\n    var sels=[\(selectorsArrayString)];\n    for(var i=0;i<sels.length;i++){ var el=document.querySelector(sels[i]); if(el){ el.click(); return 'clicked:'+sels[i]; } }\n    if(window.customBack){ try{ window.customBack(); return 'customBack'; } catch(e){} }\n    if(window.history && window.history.length>1){ window.history.back(); return 'history.back'; }\n    return 'no-op';\n  } catch(e){ return 'error:'+e.toString(); }\n})()"
        webView.evaluateJavaScript(js) { result, error in
            if let error = error { self.lastJSResult = "error: \(error.localizedDescription)"; self.showJSResultAlert = true; return }
            if let res = result as? String {
                self.lastJSResult = res
                if testOnly { self.showJSResultAlert = true; return }
                if res.hasPrefix("no-op") || res.hasPrefix("error") { self.showNoBackAlert = true; return }
            } else { self.lastJSResult = "(no string result)"; self.showJSResultAlert = true }
        }
    }
}

struct WebViewClean: UIViewRepresentable {
    let url: URL
    @ObservedObject var store: WebViewCleanStore

    init(url: URL, store: WebViewCleanStore) { self.url = url; self.store = store }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wk = WKWebView(frame: .zero, configuration: config)
        wk.navigationDelegate = context.coordinator
        wk.allowsBackForwardNavigationGestures = true
        wk.load(URLRequest(url: url))
        DispatchQueue.main.async { store.webView = wk }
        return wk
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewClean
        init(_ parent: WebViewClean) { self.parent = parent }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
    }
}

#else

// Stubs for non-UIKit platforms to avoid analyzer/type errors
struct WebViewCleanModal: View {
    let url: URL
    var body: some View { Text("WebView non disponibile su questa piattaforma") }
}

struct WebViewClean: View {
    let url: URL
    var body: some View { EmptyView() }
}

#endif
