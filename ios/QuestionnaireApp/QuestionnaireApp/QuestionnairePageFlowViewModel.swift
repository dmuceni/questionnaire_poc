import Foundation
import Combine

@MainActor
final class QuestionnairePageFlowViewModel: ObservableObject {
    @Published private(set) var pages: [QuestionnairePage] = []
    @Published private(set) var currentPageIndex: Int = 0
    @Published private(set) var pageAnswers: [String: [String: CodableValue]] = [:]
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var completed = false
    @Published private(set) var progress: Int = 0
    @Published var shouldDismiss = false

    private let cluster: String
    private let apiClient: APIClient
    var onProgressChanged: (() -> Void)?

    init(cluster: String, apiClient: APIClient = .shared) {
        self.cluster = cluster
        self.apiClient = apiClient
    }

    var currentPage: QuestionnairePage? {
        guard currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }
    
    var canGoBack: Bool {
        return currentPageIndex > 0
    }
    
    var isLastPage: Bool {
        return currentPageIndex >= pages.count - 1
    }

    func load() {
        Task { await loadData() }
    }

    func goToNextPage(with answers: [String: CodableValue]) async {
        guard let currentPage = currentPage else { return }
        
        // Salva le risposte della pagina corrente
        pageAnswers[currentPage.id] = answers
        await apiClient.savePageAnswers(answers, cluster: cluster, pageId: currentPage.id)
        
        updateProgress()
        onProgressChanged?()
        
        // Determina la prossima pagina
        if let nextPageId = determineNextPage(currentPage: currentPage, answers: answers) {
            if let nextPageIndex = pages.firstIndex(where: { $0.id == nextPageId }) {
                currentPageIndex = nextPageIndex
            } else {
                // Pagina non trovata, completa il questionario
                completed = true
            }
        } else {
            // Nessuna pagina successiva, completa il questionario
            completed = true
        }
    }
    
    func goToPreviousPage() {
        if canGoBack {
            currentPageIndex -= 1
        } else {
            shouldDismiss = true
        }
    }
    
    func getAnswersForPage(_ pageId: String) -> [String: CodableValue] {
        return pageAnswers[pageId] ?? [:]
    }

    // MARK: - Private

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let pagesTask = apiClient.fetchPages(cluster: cluster)
            async let answersTask = apiClient.fetchPageAnswers(cluster: cluster)

            let (pagesResponse, pageAnswers) = try await (pagesTask, answersTask)
            self.pages = pagesResponse.pages
            self.pageAnswers = pageAnswers
            
            // Determina la pagina corrente basata sulle risposte esistenti
            currentPageIndex = findCurrentPageIndex()
            completed = checkIfCompleted()
            
            print("🔍 DEBUG: Loaded \(pages.count) pages for cluster: \(cluster)")
            print("🔍 DEBUG: Current page index: \(currentPageIndex)")
            print("🔍 DEBUG: Completed: \(completed)")
            
            updateProgress()
        } catch {
            print("🔍 DEBUG: Error loading pages: \(error)")
            errorMessage = "Errore di caricamento: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func findCurrentPageIndex() -> Int {
        // Trova la prima pagina che non è stata completata
        for (index, page) in pages.enumerated() {
            let answers = pageAnswers[page.id] ?? [:]
            let requiredQuestions = page.questions.filter { $0.required }
            
            let isPageComplete = requiredQuestions.allSatisfy { question in
                answers[question.id] != nil
            }
            
            if !isPageComplete {
                return index
            }
        }
        
        // Tutte le pagine sono complete, va all'ultima
        return max(0, pages.count - 1)
    }
    
    private func checkIfCompleted() -> Bool {
        return pages.allSatisfy { page in
            let answers = pageAnswers[page.id] ?? [:]
            let requiredQuestions = page.questions.filter { $0.required }
            
            return requiredQuestions.allSatisfy { question in
                answers[question.id] != nil
            }
        }
    }
    
    private func determineNextPage(currentPage: QuestionnairePage, answers: [String: CodableValue]) -> String? {
        guard let navigation = currentPage.nextPage else { return nil }
        
        // Controlla le condizioni
        if let conditions = navigation.conditions {
            for condition in conditions {
                if answers[condition.questionId]?.stringValue == condition.value {
                    return condition.nextPage
                }
            }
        }
        
        // Usa la pagina di default
        return navigation.default
    }

    private func updateProgress() {
        guard !pages.isEmpty else {
            progress = 0
            return
        }
        
        var totalQuestions = 0
        var answeredQuestions = 0
        
        for page in pages {
            for question in page.questions {
                totalQuestions += 1
                
                // Controlla se la domanda ha una risposta
                let hasAnswer = pageAnswers.values.contains { answers in
                    answers[question.id] != nil
                }
                
                if hasAnswer {
                    answeredQuestions += 1
                }
            }
        }
        
        if totalQuestions == 0 {
            progress = 0
        } else {
            progress = completed ? 100 : min(Int(round(Double(answeredQuestions) / Double(totalQuestions) * 100.0)), 99)
        }
    }
}