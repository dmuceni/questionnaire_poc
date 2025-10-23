import SwiftUI
import WebKit

// Use the canonical WebView and WebViewStore defined in Views/WebViewScreen.swift
// This file should only provide the modal wrapper.
struct WebViewModal: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var store = WebViewStore()
    let url: URL
    var backSelectors: [String]? = nil

    @State private var lastJSResult: String? = nil
    @State private var showNoBackAlert: Bool = false
    @State private var showJSResultAlert: Bool = false

    var body: some View {
        NavigationView {
            WebView(url: url, store: store)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { triggerPageBack() }) {
                            HStack { Image(systemName: "chevron.left"); Text("Indietro") }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            Button("Test Back") { triggerPageBack(testOnly: true) }
                            Button("Chiudi") { presentationMode.wrappedValue.dismiss() }
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
    }

    private func triggerPageBack(testOnly: Bool = false) {
        guard let webView = store.webView else { showNoBackAlert = true; return }
        let selectors = (backSelectors?.isEmpty == false) ? backSelectors! : ["button.back", ".back-button", "#back", "a[rel=back]"]
        let selectorsArrayString = selectors.map { "\'\($0)\'" }.joined(separator: ",")
        let js = "(function(){\n  try{\n    var sels=[\(selectorsArrayString)];\n    for(var i=0;i<sels.length;i++){ var el=document.querySelector(sels[i]); if(el){ el.click(); return 'clicked:'+sels[i]; } }\n    if(window.customBack){ try{ window.customBack(); return 'customBack'; } catch(e){} }\n    if(window.history && window.history.length>1){ window.history.back(); return 'history.back'; }\n    return 'no-op';\n  } catch(e){ return 'error:'+e.toString(); }\n})()"
        webView.evaluateJavaScript(js) { result, error in
            if let error = error { lastJSResult = "error: \(error.localizedDescription)"; showJSResultAlert = true; return }
            if let res = result as? String {
                lastJSResult = res
                if testOnly { showJSResultAlert = true; return }
                if res.hasPrefix("no-op") || res.hasPrefix("error") { showNoBackAlert = true; return }
            } else {
                lastJSResult = "(no string result)"; showJSResultAlert = true
            }
        }
    }
}
// WebView implementation moved to Views/WebViewScreen.swift
