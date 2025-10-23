import SwiftUI

struct QuestionnairePageFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var listViewModel: QuestionnaireListViewModel
    @StateObject private var viewModel: QuestionnairePageFlowViewModel

    let cluster: String
    let title: String

    init(cluster: String, title: String) {
        self.cluster = cluster
        self.title = title
        _viewModel = StateObject(wrappedValue: QuestionnairePageFlowViewModel(cluster: cluster))
    }

    var body: some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WebViewChevronBackTapped"))) { _ in
                print("🔔 QuestionnairePageFlowView: received WebViewChevronBackTapped")
                viewModel.goToPreviousPage()
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
            CompletionView {
                dismiss()
            }
        } else if let currentPage = viewModel.currentPage {
            QuestionnairePageView(
                page: currentPage,
                savedAnswers: viewModel.getAnswersForPage(currentPage.id),
                onContinue: { answers in
                    Task {
                        print("🔍 QuestionnairePageFlowView.onContinue: called for page=\(currentPage.id) with answers=\(answers)")
                        print("🔍 QuestionnairePageFlowView: before goToNextPage currentIndex=\(viewModel.currentPageIndex) pages=[\(viewModel.pages.map({ $0.id }).joined(separator: ","))]")
                        await viewModel.goToNextPage(with: answers)
                        print("🔍 QuestionnairePageFlowView: after goToNextPage currentIndex=\(viewModel.currentPageIndex) currentPage=\(viewModel.currentPage?.id ?? "nil")")
                    }
                },
                onBack: {
                    viewModel.goToPreviousPage()
                }
            )
        } else {
            VStack(spacing: 16) {
                Text("Nessuna pagina disponibile")
                    .font(.title2)
                
                Button("Torna all'elenco") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct CompletionView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
            
            // Success Message
            VStack(spacing: 16) {
                Text("Questionario Completato!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Grazie per aver condiviso le tue informazioni. Le tue risposte sono state salvate con successo.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Progress Bar at 100%
            VStack(spacing: 8) {
                ProgressBarView(percentage: 100)
                Text("100% Completato")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Return Button
            Button(action: onDismiss) {
                HStack {
                    Text("Torna all'elenco")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "house.fill")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(16)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct QuestionnairePageFlowView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            QuestionnairePageFlowView(cluster: "test", title: "Test Questionario")
                .environmentObject(QuestionnaireListViewModel())
        }
    }
}