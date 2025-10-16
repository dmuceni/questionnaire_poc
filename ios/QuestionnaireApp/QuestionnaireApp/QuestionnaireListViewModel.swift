import Foundation

@MainActor
final class QuestionnaireListViewModel: ObservableObject {
    @Published var questionnaires: [QuestionnaireProgress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func load() {
        Task { await loadProgress() }
    }

    func refresh() {
        Task { await loadProgress(showLoader: false) }
    }

    func resetProgress(for cluster: String) {
        Task {
            do {
                try await apiClient.resetPageAnswers(cluster: cluster)
                questionnaires = questionnaires.map { item in
                    guard item.cluster == cluster else { return item }
                    return QuestionnaireProgress(
                        cluster: item.cluster, 
                        title: item.title, 
                        percent: 0,
                        questionnaireTitle: item.questionnaireTitle,
                        questionnaireSubtitle: item.questionnaireSubtitle
                    )
                }
            } catch {
                errorMessage = "Impossibile azzerare il questionario"
            }
        }
    }

    private func loadProgress(showLoader: Bool = true) async {
        if showLoader { isLoading = true }
        errorMessage = nil
        do {
            let items = try await apiClient.fetchProgress()
            questionnaires = items
        } catch {
            errorMessage = "Errore nel recupero dei questionari"
        }
        isLoading = false
    }
}
