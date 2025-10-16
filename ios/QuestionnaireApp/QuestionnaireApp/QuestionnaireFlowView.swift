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
            // Nasconde il back di default per evitare doppio pulsante quando SwiftUI genera automaticamente il back
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.previousPage()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Indietro")
                        }
                    }
                    .accessibilityLabel("Indietro")
                }
            }
            .onAppear {
                viewModel.onProgressChanged = { listViewModel.refresh() }
                
                // Try page mode first, fallback to question mode
                viewModel.usePageMode = true
                viewModel.loadPages()
            }
            .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
            .onChange(of: viewModel.errorMessage) { errorMessage in
                // If page mode fails, try question mode
                if errorMessage != nil && viewModel.usePageMode {
                    print("🔄 Page mode failed, falling back to question mode")
                    viewModel.usePageMode = false
                    viewModel.load()
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
            // New completion style
            completionView
        } else if viewModel.usePageMode {
            // Page mode
            pageBasedView
        } else if let question = currentQuestion {
            // Question mode with cards
            pageStyleView
        } else {
            VStack(spacing: 16) {
                Text("DEBUG INFO:")
                    .font(.headline)
                Text("Questions count: \(viewModel.questions.count)")
                Text("Current ID: \(viewModel.currentQuestionID ?? "nil")")
                Text("Completed: \(viewModel.completed ? "YES" : "NO")")
                Text("Loading: \(viewModel.isLoading ? "YES" : "NO")")
                if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                }
                
                Text("Nessuna domanda disponibile")
                    .font(.title2)
                    .padding(.top)
                
                Button("Torna all'elenco") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var pageBasedView: some View {
        if let currentPage = viewModel.currentPage {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        // Progress indicator
                        ProgressBarView(percentage: viewModel.progress)
                            .id("top") // Identificatore per lo scroll
                        
                        if let pageTitle = currentPage.title, !pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(pageTitle)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .padding(.bottom)
                        }
                        
                        // RIMOSSO titolo pagina
                        ForEach(currentPage.questions) { question in
                            questionCard(for: question)
                        }
                        
                        Button(action: {
                            // Clear any previous error messages
                            viewModel.errorMessage = nil
                            
                            // Save answers and proceed
                            viewModel.saveCurrentPageAnswers()
                            if currentPage.isLast {
                                viewModel.completed = true
                            } else {
                                viewModel.nextPage()
                            }
                        }) {
                            HStack {
                                Text(currentPage.isLast ? "Completa" : "Continua")
                                    .fontWeight(.semibold)
                                Spacer()
                                Image(systemName: currentPage.isLast ? "checkmark" : "arrow.right")
                            }
                            .padding()
                            .background(viewModel.canProceedToNextPage() ? Color.accentColor : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!viewModel.canProceedToNextPage())
                        .padding(.top)
                    }
                    .padding()
                }
                .onChange(of: viewModel.currentPage?.id) { _ in
                    // Scroll automatico verso l'alto quando cambia pagina
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        } else {
            Text("Nessuna pagina disponibile")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var completionView: some View {
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
            
            ProgressBarView(percentage: 100)
            
            Button("Torna all'elenco") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    private var pageStyleView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Progress indicator
                    ProgressBarView(percentage: viewModel.progress)
                        .id("top") // Identificatore per lo scroll
                    
                    // Current question in a card style
                    if let question = currentQuestion {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(question.text)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.leading)
                            
                            QuestionView(
                                question: question,
                                answer: viewModel.answers[question.id],
                                onSelectRating: viewModel.answerRating,
                                onSelectOption: viewModel.answerOption,
                                onUpdateOpen: viewModel.answerOpenQuestion,
                                onSelectMultipleChoice: viewModel.answerMultipleChoice
                            )
                        }
                        .padding(20)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.currentQuestionID) { _ in
                // Scroll automatico verso l'alto quando cambia domanda
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func questionCard(for question: Question) -> some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            QuestionView(
                question: question,
                answer: viewModel.answers[question.id],
                onSelectRating: { rating in
                    viewModel.answerPageRating(questionId: question.id, rating: rating)
                },
                onSelectOption: { optionId in
                    viewModel.answerPageOption(questionId: question.id, optionId: optionId)
                },
                onUpdateOpen: { text in
                    viewModel.answerPageOpenQuestion(questionId: question.id, text: text)
                },
                onSelectMultipleChoice: { selectedOptions in
                    viewModel.answerPageMultipleChoice(questionId: question.id, selectedOptions: selectedOptions)
                }
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
        .overlay(alignment: .top) {
            if question.type == .rating {
                scaleGradientOverlay
            }
        }
    }
    
    private var scaleGradientOverlay: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.8),
                Color.accentColor.opacity(0.4),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
