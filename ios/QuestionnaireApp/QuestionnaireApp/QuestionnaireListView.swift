import SwiftUI

// Se il file WebViewScreen.swift è nello stesso target, non serve import. Se persiste errore, dichiara qui la struct WebViewScreen:

// Note: `WebViewScreen` and `WebView` are defined in Views/WebViewScreen.swift

struct QuestionnaireListView: View {
    @EnvironmentObject private var viewModel: QuestionnaireListViewModel
    @Binding var path: [QuestionnaireRoute]
    
    @State private var navigateToWebView = false
    var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Sezione "Il tuo stile"
                VStack(alignment: .leading, spacing: 16) {
                    Text("Il tuo stile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Rendi l'app davvero tua con un aspetto che rispecchia il tuo stile.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Personalizza aspetto")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Scegli colori, temi e layout")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    .onTapGesture {
                        // Link finto - nessuna azione
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
                    .padding(.horizontal)
                VStack(alignment: .leading, spacing: 16) {
                    Text("La tua esperienza")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Ottieni solo i contenuti e le offerte adatte a te, senza perdere tempo.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                ForEach(viewModel.questionnaires) { questionnaire in
                    QuestionnaireRow(item: questionnaire, onTap: {
                        path.append(.questionnaire(cluster: questionnaire.cluster, title: questionnaire.title))
                    }, onRestart: {
                        viewModel.resetProgress(for: questionnaire.cluster)
                        path.append(.questionnaire(cluster: questionnaire.cluster, title: questionnaire.title))
                    })
                }
            }
            .padding()
        }
    }
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Caricamento...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Text(error)
                        .foregroundColor(.red)
                    Button("Riprova") {
                        viewModel.load()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                listContent
            }
        }
        .navigationTitle("Personalizzazione")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Apri WebView") { navigateToWebView = true }
                Button(action: viewModel.refresh) {
                    Text("\u{27F3}")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel(Text("Aggiorna questionari"))
                .disabled(viewModel.isLoading)
            }
        }
        .fullScreenCover(isPresented: $navigateToWebView) {
            WebViewCleanModal(url: URL(string: "http://questionnaire-poc.onrender.com/")!, title: "Personalizzazione", onBack: {
                // Esegue lo step indietro dell'app: se il NavigationPath ha elementi, rimuoverli; altrimenti chiudi il modal
                if !path.isEmpty {
                    path.removeLast()
                } else {
                    navigateToWebView = false
                }
            })
            .interactiveDismissDisabled(true)
        }
        // Hide parent navigation back button while the webview is presented so tapping
        // the parent's '<' doesn't immediately close the modal webview.
        .navigationBarBackButtonHidden(navigateToWebView)
        .task { viewModel.load() }
    }

}

struct QuestionnaireRow: View {
    let item: QuestionnaireProgress
    let onTap: () -> Void
    let onRestart: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.questionnaireTitle ?? item.title)
                    .font(.headline)
                    .foregroundColor(.primary)

                if let subtitle = item.questionnaireSubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Text("\(item.percent)%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                if item.percent >= 100 {
                    Button("Ricomincia") { onRestart() }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onTapGesture { onTap() }
        .contextMenu { if item.percent >= 100 { Button("Ricomincia", action: onRestart) } }
    }
}
    
    struct QuestionnaireListView_Previews: PreviewProvider {
        @State static var path: [QuestionnaireRoute] = []
        
        static var previews: some View {
            QuestionnaireListView(path: $path)
                .environmentObject(previewModel)
        }
        
        private static var previewModel: QuestionnaireListViewModel = {
            let vm = QuestionnaireListViewModel()
            vm.questionnaires = [
                QuestionnaireProgress(
                    cluster: "preview_cluster",
                    title: "Questionario di esempio",
                    percent: 40,
                    questionnaireTitle: "Titolo questionario",
                    questionnaireSubtitle: "Sottotitolo descrittivo placeholder."
                )
            ]
            return vm
        }()
    }

