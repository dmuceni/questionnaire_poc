import SwiftUI

struct QuestionnaireFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var listViewModel: QuestionnaireListViewModel
    @StateObject private var viewModel: QuestionnaireFlowViewModel

    let cluster: String
    let title: String

    init(cluster: String, title: String) {
        self.cluster = cluster
        self.title = title
        _viewModel = StateObject(wrappedValue: QuestionnaireFlowViewModel(cluster: cluster))
    }

    var body: some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Indietro") {
                        viewModel.goBack()
                    }
                }
            }
            .onAppear {
                viewModel.onProgressChanged = { listViewModel.refresh() }
                viewModel.load()
            }
            .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Caricamento...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 16) {
                Text(error)
                    .foregroundColor(.red)
                Button("Torna all'elenco") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.completed {
            VStack(spacing: 24) {
                ProgressBarView(percentage: 100)
                Text("Questionario completato")
                    .font(.title2)
                    .fontWeight(.semibold)
                Button("Torna all'elenco") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let question = currentQuestion {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProgressBarView(percentage: viewModel.progress)
                    QuestionView(
                        question: question,
                        answer: viewModel.answers[question.id],
                        onSelectRating: viewModel.answerRating,
                        onSelectOption: viewModel.answerOption,
                        onUpdateOpen: viewModel.answerOpenQuestion
                    )
                }
                .padding()
            }
        } else {
            Text("Nessuna domanda disponibile")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var currentQuestion: Question? {
        guard let id = viewModel.currentQuestionID else { return nil }
        return viewModel.questions.first(where: { $0.id == id }) ?? viewModel.questions.first
    }
}

struct QuestionnaireFlowView_Previews: PreviewProvider {
    static var previews: some View {
        QuestionnaireFlowView(cluster: "health", title: "Salute")
            .environmentObject(QuestionnaireListViewModel())
    }
}
