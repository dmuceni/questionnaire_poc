import Foundation
import Combine

@MainActor
final class QuestionnaireFlowViewModel: ObservableObject {
    @Published private(set) var questions: [Question] = []
    @Published private(set) var answers: [String: CodableValue] = [:]
    @Published private(set) var stack: [String] = []
    @Published private(set) var currentQuestionID: String?
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

    func load() {
        Task { await loadData() }
    }

    func answerCurrent(with value: CodableValue) {
        guard let currentID = currentQuestionID, let question = questions.first(where: { $0.id == currentID }) else { return }
        applyAnswer(value, for: question)
    }

    func answerOpenQuestion(text: String) {
        answerCurrent(with: .string(text))
    }

    func answerRating(_ rating: Int) {
        answerCurrent(with: .int(rating))
    }

    func answerOption(id: String) {
        answerCurrent(with: .string(id))
    }

    func goBack() {
        guard !stack.isEmpty else {
            shouldDismiss = true
            return
        }

        if stack.count == 1 {
            shouldDismiss = true
            return
        }

        var newStack = stack
        newStack.removeLast()
        stack = newStack
        let previousID = newStack.last
        currentQuestionID = previousID
        completed = false

        if let previousID {
            answers.removeValue(forKey: previousID)
            Task { await apiClient.saveAnswers(answers, cluster: cluster) }
        }

        updateProgress()
        onProgressChanged?()
    }

    // MARK: - Private

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let questionsTask = apiClient.fetchQuestionnaire(cluster: cluster)
            async let answersTask = apiClient.fetchUserAnswers(cluster: cluster)

            let (questions, answers) = try await (questionsTask, answersTask)
            self.questions = questions
            self.answers = answers

            let result = buildFullPath(questions: questions, answers: answers)
            var resolvedPath = result.path
            if resolvedPath.isEmpty, let first = questions.first?.id {
                resolvedPath = [first]
            }

            stack = resolvedPath
            currentQuestionID = resolvedPath.last ?? questions.first?.id
            completed = result.endReached && resolvedPath.allSatisfy { answers[$0] != nil }
            updateProgress()
        } catch {
            errorMessage = "Errore di caricamento"
        }
        isLoading = false
    }

    private func applyAnswer(_ value: CodableValue, for question: Question) {
        if answers[question.id] == value {
            return
        }

        var workingStack = stack
        let index: Int
        if let existing = workingStack.firstIndex(of: question.id) {
            index = existing
        } else {
            workingStack.append(question.id)
            index = workingStack.count - 1
        }

        var updatedAnswers = answers

        if index < workingStack.count - 1 {
            let toRemove = workingStack[(index + 1)...]
            toRemove.forEach { updatedAnswers.removeValue(forKey: $0) }
            workingStack = Array(workingStack.prefix(index + 1))
        } else {
            workingStack = Array(workingStack.prefix(index + 1))
        }

        updatedAnswers[question.id] = value

        var nextID: String?
        if let next = question.next {
            nextID = resolveNextID(next: next, answer: value)
        }

        if let nextID, questions.contains(where: { $0.id == nextID }) {
            workingStack.append(nextID)
            currentQuestionID = nextID
            completed = false
        } else {
            currentQuestionID = question.id
            completed = true
        }

        answers = updatedAnswers
        stack = workingStack
        updateProgress()

        Task { await apiClient.saveAnswers(updatedAnswers, cluster: cluster) }
        onProgressChanged?()
    }

    private func resolveNextID(next: QuestionNext, answer: CodableValue) -> String? {
        switch next {
        case .id(let value):
            return value
        case .mapping(let map):
            if let hit = map[answer.stringKey] {
                return hit
            }
            return map["default"]
        }
    }

    private func buildFullPath(questions: [Question], answers: [String: CodableValue]) -> (path: [String], endReached: Bool) {
        let map = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        guard let startID = questions.first?.id else { return ([], false) }
        if answers.isEmpty { return ([startID], false) }

        var path: [String] = []
        var currentID: String? = startID
        var visited: Set<String> = []
        var endReached = false
        var safety = 0

        while let id = currentID, !visited.contains(id), safety < 200 {
            safety += 1
            path.append(id)
            visited.insert(id)
            guard let question = map[id] else { break }
            guard let next = question.next else {
                endReached = true
                break
            }

            guard let answer = answers[id] else {
                break
            }

            let nextID = resolveNextID(next: next, answer: answer)
            guard let candidate = nextID, map[candidate] != nil else {
                endReached = true
                break
            }

            currentID = candidate
        }

        return (path, endReached)
    }

    private func updateProgress() {
        guard !questions.isEmpty else {
            progress = 0
            return
        }
        let answeredCount = answers.keys.filter { key in
            questions.contains(where: { $0.id == key })
        }.count
        progress = completed ? 100 : min(Int(round(Double(answeredCount) / Double(questions.count) * 100.0)), 99)
    }
}
