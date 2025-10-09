import SwiftUI

struct QuestionnaireListView: View {
    @EnvironmentObject private var viewModel: QuestionnaireListViewModel
    @Binding var path: [QuestionnaireRoute]

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
        .navigationTitle("Questionari")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: viewModel.refresh) {
                    Text("\u{27F3}")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel(Text("Aggiorna questionari"))
                .disabled(viewModel.isLoading)
            }
        }
        .task { viewModel.load() }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.questionnaires) { questionnaire in
                    QuestionnaireRow(item: questionnaire, onContinue: {
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
}

private struct QuestionnaireRow: View {
    let item: QuestionnaireProgress
    let onContinue: () -> Void
    let onRestart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.title)
                    .font(.headline)
                Spacer()
                Text("\(item.percent)%")
                    .font(.subheadline)
                    .padding(6)
                    .background(item.percent == 100 ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }

            ProgressBarView(percentage: item.percent)

            HStack {
                if item.percent < 100 {
                    Button("Continua", action: onContinue)
                        .buttonStyle(.borderedProminent)
                }
                if item.percent == 100 {
                    Button("Ricomincia", action: onRestart)
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
            QuestionnaireProgress(cluster: "health", title: "Questionario Salute", percent: 40),
            QuestionnaireProgress(cluster: "customer", title: "Customer Satisfaction", percent: 100)
        ]
        return vm
    }()
}
