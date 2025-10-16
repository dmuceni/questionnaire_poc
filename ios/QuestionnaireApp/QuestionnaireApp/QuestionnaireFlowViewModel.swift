// Uses PageFlowEngine for dynamic page routing (see PageFlowEngine.swift)
import Foundation
import Combine

// PageFlowEngine struct will be inlined at bottom of this file to avoid the need
// to update Xcode project for a new source file while refactoring.

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
    
    // Page-based properties
    @Published private(set) var pages: [QuestionnairePage] = []
    @Published private(set) var currentPageIndex: Int = 0
    @Published private(set) var pageAnswers: [String: [String: CodableValue]] = [:]
    @Published var usePageMode = false
    
    // Multiple conditional pages sequence
    @Published private(set) var conditionalPagesQueue: [String] = []
    @Published private(set) var currentConditionalIndex: Int = 0

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
    
    // MARK: - Page Mode Functions
    
    func loadPages() {
        Task { await loadPageData() }
    }
    
    var currentPage: QuestionnairePage? {
        guard currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }
    
    var conditionalPagesProgress: String {
        guard !conditionalPagesQueue.isEmpty else { return "" }
        return "(\(currentConditionalIndex + 1)/\(conditionalPagesQueue.count))"
    }
    
    func nextPage() {
        print("🔍 DEBUG: nextPage() called")
        print("🔍 DEBUG: Current page: \(currentPage?.id ?? "nil")")
        print("🔍 DEBUG: ConditionalPagesQueue: \(conditionalPagesQueue)")
        print("🔍 DEBUG: CurrentConditionalIndex: \(currentConditionalIndex)")
        
        // Save current page answers before evaluating next page
        if let page = currentPage {
            Task { await savePageAnswers(for: page) }
        }
        
        // Check if we're in the middle of a conditional pages sequence
        if !conditionalPagesQueue.isEmpty {
            print("🔍 DEBUG: We have conditional pages queue: \(conditionalPagesQueue)")
            // Check if we're currently on a conditional page that we need to move away from
            if let currentPageId = currentPage?.id,
               conditionalPagesQueue.contains(currentPageId) {
                print("🔍 DEBUG: Current page \(currentPageId) is in conditional queue")
                // Move to next conditional page in queue
                if let currentQueueIndex = conditionalPagesQueue.firstIndex(of: currentPageId) {
                    print("🔍 DEBUG: Current page index in queue: \(currentQueueIndex)")
                    let nextQueueIndex = currentQueueIndex + 1
                    
                    if nextQueueIndex < conditionalPagesQueue.count {
                        // Go to next conditional page
                        let nextConditionalPageId = conditionalPagesQueue[nextQueueIndex]
                        print("🔍 DEBUG: Next conditional page should be: \(nextConditionalPageId)")
                        if let nextPageIndex = pages.firstIndex(where: { $0.id == nextConditionalPageId }) {
                            currentPageIndex = nextPageIndex
                            currentConditionalIndex = nextQueueIndex
                            print("🔍 DEBUG: ✅ Moving to conditional page \(nextQueueIndex + 1)/\(conditionalPagesQueue.count): \(nextConditionalPageId)")
                            updateProgress()
                            onProgressChanged?()
                            return
                        } else {
                            print("🔍 DEBUG: ❌ Could not find page index for \(nextConditionalPageId)")
                        }
                    } else {
                        // Finished all conditional pages
                        print("🔍 DEBUG: ✅ Completed all conditional pages (\(conditionalPagesQueue.count) total)")
                        conditionalPagesQueue = []
                        currentConditionalIndex = 0
                        
                        // Check if current page has a defaultAction before completing
                        if let currentPageData = currentPage,
                           let routing = currentPageData.conditionalRouting {
                            print("🔍 DEBUG: Checking defaultAction for current page: \(currentPageData.id)")
                            if routing.defaultAction == "complete" {
                                print("🔍 DEBUG: DefaultAction is 'complete', finishing questionnaire")
                                completed = true
                            } else {
                                print("🔍 DEBUG: DefaultAction is '\(routing.defaultAction)', navigating to that page")
                                // Navigate to the defaultAction page
                                if let nextPageIndex = pages.firstIndex(where: { $0.id == routing.defaultAction }) {
                                    currentPageIndex = nextPageIndex
                                    updateProgress()
                                    onProgressChanged?()
                                } else {
                                    print("🔍 DEBUG: ❌ Could not find page with id: \(routing.defaultAction)")
                                    completed = true
                                }
                            }
                        } else {
                            print("🔍 DEBUG: No conditional routing found, completing questionnaire")
                            completed = true
                        }
                        return
                    }
                } else {
                    print("🔍 DEBUG: ❌ Could not find current page \(currentPageId) in queue")
                }
            } else {
                print("🔍 DEBUG: Current page \(currentPage?.id ?? "nil") is NOT in conditional queue or no current page")
            }
            
            // If we're not on a conditional page but have queue, start the sequence
            if currentConditionalIndex < conditionalPagesQueue.count {
                let nextPageId = conditionalPagesQueue[currentConditionalIndex]
                if let nextPageIndex = pages.firstIndex(where: { $0.id == nextPageId }) {
                    currentPageIndex = nextPageIndex
                    print("🔍 DEBUG: Starting conditional sequence: \(nextPageId) (1/\(conditionalPagesQueue.count))")
                    updateProgress()
                    onProgressChanged?()
                    return
                }
            }
        }
        
        // Check if current page has conditional routing (first time evaluation)
        if let routing = currentPage?.conditionalRouting, conditionalPagesQueue.isEmpty {
            let nextPageId = evaluateConditionalRouting(routing: routing)
            print("🔍 DEBUG: Conditional routing returned nextPageId: \(nextPageId ?? "nil")")
            if let nextPageId = nextPageId {
                // Find the index of the next page to go to
                print("🔍 DEBUG: Looking for page with id: \(nextPageId)")
                print("🔍 DEBUG: Available page ids: \(pages.map { $0.id })")
                if let nextPageIndex = pages.firstIndex(where: { $0.id == nextPageId }) {
                    print("🔍 DEBUG: Found page at index: \(nextPageIndex)")
                    currentPageIndex = nextPageIndex
                    updateProgress()
                    onProgressChanged?()
                    return
                } else {
                    print("🔍 DEBUG: ❌ Page with id '\(nextPageId)' not found in pages array!")
                }
            }
            // If routing says to complete or no valid page found, complete the questionnaire
            print("🔍 DEBUG: Completing questionnaire - no valid next page found")
            completed = true
            return
        }
        
        // Default logic: go to next page in sequence
        guard currentPageIndex < pages.count - 1 else {
            completed = true
            return
        }
        
        currentPageIndex += 1
        updateProgress()
        onProgressChanged?()
    }
    
    private func evaluateConditionalRouting(routing: ConditionalRouting) -> String? {
        // Sort rules by priority (lower number = higher priority)
        let sortedRules = routing.rules.sorted { $0.priority < $1.priority }
        
        // Collect ALL pages that meet conditions
        var matchingPages: [String] = []
        
        // Check each rule in priority order
        for rule in sortedRules {
            print("🔍 DEBUG: Checking rule for \(rule.condition.questionId): operator \(rule.condition.operatorType) value \(rule.condition.value)")
            
            let conditionMet = evaluateCondition(
                questionId: rule.condition.questionId,
                operatorType: rule.condition.operatorType,
                expectedValue: rule.condition.value
            )
            
            if conditionMet {
                print("🔍 DEBUG: ✅ Condition MET for \(rule.condition.questionId): \(rule.condition.operatorType) \(rule.condition.value) -> \(rule.nextPage)")
                matchingPages.append(rule.nextPage)
            } else {
                print("🔍 DEBUG: ❌ Condition NOT met for \(rule.condition.questionId): \(rule.condition.operatorType) \(rule.condition.value)")
            }
        }
        
        if !matchingPages.isEmpty {
            // Store all matching pages in queue
            conditionalPagesQueue = matchingPages
            currentConditionalIndex = 0
            print("🔍 DEBUG: Found \(matchingPages.count) matching pages: \(matchingPages)")
            return matchingPages.first
        }
        
        // No conditions met, check default action
        print("🔍 DEBUG: No conditions met, using default action: \(routing.defaultAction)")
        return routing.defaultAction == "complete" ? nil : routing.defaultAction
    }
    
    private func evaluateCondition(questionId: String, operatorType: String, expectedValue: String) -> Bool {
        // Ottieni la risposta dell'utente
        let userAnswer = getUserAnswer(questionId: questionId)
        
        print("🔍 DEBUG: Got user answer for \(questionId): '\(userAnswer)', expected: '\(expectedValue)', operator: '\(operatorType)'")
        
        // Se l'operatore è "==" o "!=", fai confronto diretto tra stringhe
        if operatorType == "==" || operatorType == "!=" {
            let result = operatorType == "==" ? userAnswer == expectedValue : userAnswer != expectedValue
            print("🔍 DEBUG: String comparison: '\(userAnswer)' \(operatorType) '\(expectedValue)' = \(result)")
            return result
        }
        
        // Per operatori numerici, prova a convertire entrambi i valori in numeri
        guard let userValue = Double(userAnswer), let expectedDoubleValue = Double(expectedValue) else {
            print("🔍 DEBUG: Cannot convert to numbers: user='\(userAnswer)', expected='\(expectedValue)'")
            return false
        }
        
        print("🔍 DEBUG: Numeric comparison: \(userValue) \(operatorType) \(expectedDoubleValue)")
        
        switch operatorType {
        case ">=": return userValue >= expectedDoubleValue
        case ">": return userValue > expectedDoubleValue
        case "<": return userValue < expectedDoubleValue
        case "<=": return userValue <= expectedDoubleValue
        default:
            print("⚠️ Unknown operator: \(operatorType)")
            return false
        }
    }
    
    private func getUserAnswer(questionId: String) -> String {
        // Cerca la risposta nella mappa delle risposte
        if let answer = answers[questionId] {
            return answer.stringKey
        }
        
        print("🔍 DEBUG: No answer found for question: \(questionId)")
        return ""
    }
    
    private func getRatingAnswer(_ questionId: String) -> Int {
        print("🔍 DEBUG: Looking for answer with questionId: '\(questionId)'")
        print("🔍 DEBUG: Available answers: \(answers.keys.sorted())")
        
        guard let answer = answers[questionId] else { 
            print("🔍 DEBUG: No answer found for '\(questionId)', returning 0")
            return 0 
        }
        
        switch answer {
        case .int(let value):
            print("🔍 DEBUG: Found rating answer for '\(questionId)': \(value)")
            return value
        default:
            print("🔍 DEBUG: Answer for '\(questionId)' is not an int: \(answer), returning 0")
            return 0
        }
    }
    
    func previousPage() {
        print("🔍 DEBUG: previousPage() called, currentPageIndex: \(currentPageIndex)")
        guard currentPageIndex > 0 else { shouldDismiss = true; return }
        // Cerca la precedente pagina raggiungibile scorrendo all'indietro
        var target = currentPageIndex - 1
        while target >= 0 {
            if PageFlowEngine.isPageReachable(pages: pages, targetIndex: target, answers: answers) { break }
            target -= 1
        }
        if target < 0 { shouldDismiss = true; return }
        currentPageIndex = target
        updateProgress()
        onProgressChanged?()
    }
    
    func saveCurrentPageAnswers() {
        guard let currentPage = self.currentPage else { return }
        
        // Force save any pending open text answers before saving
        forceSavePendingOpenTextAnswers(for: currentPage)
        
        Task {
            await savePageAnswers(for: currentPage)
        }
    }
    
    private func forceSavePendingOpenTextAnswers(for page: QuestionnairePage) {
        // This will be called by the view to ensure all pending text is saved
        // The view will call answerPageOpenQuestion for each unsaved text field
        NotificationCenter.default.post(name: .forceSaveOpenTextAnswers, object: page.id)
    }
    
    // MARK: - Validation Functions
    
    func canProceedToNextPage() -> Bool {
        guard let page = currentPage else { return false }
        
        for question in page.questions {
            if question.isRequired && !isQuestionAnswered(question) {
                return false
            }
        }
        return true
    }
    
    private func isQuestionAnswered(_ question: Question) -> Bool {
        guard let answer = answers[question.id] else { return false }
        
        switch answer {
        case .string(let value):
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .int(_):
            return true // Rating questions always have a valid value if present
        case .stringArray(let values):
            return !values.isEmpty // Multiple choice needs at least one selection
        }
    }
    
    private func loadPageData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let pagesTask = apiClient.fetchPages(cluster: cluster)
            async let pageAnswersTask = apiClient.fetchPageAnswers(cluster: cluster)
            
            let (pagesResponse, pageAnswers) = try await (pagesTask, pageAnswersTask)
            self.pages = pagesResponse.pages
            self.pageAnswers = pageAnswers
            
            // Popola answers con le risposte caricate dalle pagine
            for (pageId, pageAnswers) in pageAnswers {
                for (questionId, answer) in pageAnswers {
                    answers[questionId] = answer
                }
            }
            
            print("🔍 DEBUG: Loaded \(pages.count) pages for cluster: \(cluster)")
            print("🔍 DEBUG: User has page answers for \(pageAnswers.count) pages")
            print("🔍 DEBUG: Populated \(answers.count) individual answers")
            
            // Determina la pagina corrente basandosi sulle risposte esistenti
            currentPageIndex = determineStartingPageIndex()
            
            // Verifica se il questionario è completato
            completed = checkQuestionnaireCompletion()
            
            print("🔍 DEBUG: Starting from page index: \(currentPageIndex)")
            print("🔍 DEBUG: Questionnaire completed: \(completed)")
            updateProgress()
        } catch {
            print("🔍 DEBUG: Error loading page data: \(error)")
            errorMessage = "Errore di caricamento: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func savePageAnswers(for page: QuestionnairePage) async {
        let pageAnswersToSave = pageAnswers[page.id] ?? [:]
        print("🔍 DEBUG: savePageAnswers(for: \(page.id)) local keys before POST: \(Array(pageAnswersToSave.keys)) count=\(pageAnswersToSave.count)")
        
        do {
            await apiClient.savePageAnswers(pageAnswersToSave, cluster: cluster, pageId: page.id)
            
            // Se stiamo salvando la pagina degli interessi, controlla se dobbiamo cancellare le pagine di approfondimento
            if page.id == "page_interessi" {
                await cleanupDrillDownPages()
            }
        } catch {
            print("🔍 DEBUG: Error saving page answers: \(error)")
            errorMessage = "Errore nel salvataggio: \(error.localizedDescription)"
        }
    }
    
    private func cleanupDrillDownPages() async {
        // Sostituito da cleanup dinamico basato su reachability: eliminiamo risposte di pagine non più raggiungibili
        let cleaned = await PageFlowEngine.cleanupUnreachablePages(pages: pages, answers: answers, pageAnswers: pageAnswers) { pageId in
            await apiClient.savePageAnswers([:], cluster: cluster, pageId: pageId)
        }
        pageAnswers = cleaned
    }

    func answerCurrent(with value: CodableValue) {
        guard let currentID = currentQuestionID, let question = questions.first(where: { $0.id == currentID }) else { return }
        applyAnswer(value, for: question)
    }

    func answerOpenQuestion(text: String) {
        answerCurrent(with: .string(text))
    }
    
    // Method for page-based open question answers
    /// Stores an open text answer for a question on the current page (no routing reset)
    func answerPageOpenQuestion(questionId: String, text: String) {
        setPageAnswer(questionId: questionId, value: .string(text), resetRouting: false, logLabel: "open")
    }

    func answerRating(_ rating: Int) {
        answerCurrent(with: .int(rating))
    }
    
    // Method for page-based rating answers
    /// Stores a rating answer for a question on the current page and resets conditional routing
    func answerPageRating(questionId: String, rating: Int) {
        setPageAnswer(questionId: questionId, value: .int(rating), resetRouting: true, logLabel: "rating")
    }
    
    func answerOption(id: String) {
        answerCurrent(with: .string(id))
    }
    
    func answerMultipleChoice(selectedOptions: [String]) {
        answerCurrent(with: .stringArray(selectedOptions))
    }
    
    // Method for page-based option answers
    /// Stores a single-choice option answer for a question on the current page and resets conditional routing
    func answerPageOption(questionId: String, optionId: String) {
        setPageAnswer(questionId: questionId, value: .string(optionId), resetRouting: true, logLabel: "option")
    }
    
    // Method for page-based multiple choice answers
    /// Stores a multi-choice answer array for a question on the current page and resets conditional routing
    func answerPageMultipleChoice(questionId: String, selectedOptions: [String]) {
        setPageAnswer(questionId: questionId, value: .stringArray(selectedOptions), resetRouting: true, logLabel: "multipleChoice")
    }
    
    // MARK: - Generic page answer setter
    /// Centralised helper to register an answer both in the flat `answers` map and
    /// inside the current page entry of `pageAnswers`.
    /// - Parameters:
    ///   - questionId: The identifier of the question being answered
    ///   - value: CodableValue representing the answer
    ///   - resetRouting: Whether conditional routing intermediate state must be cleared
    ///   - logLabel: Short label for debug logging context
    private func setPageAnswer(questionId: String, value: CodableValue, resetRouting: Bool, logLabel: String) {
        // Skip if identical (avoids unnecessary routing reset and logs)
        if answers[questionId] == value { return }
        answers[questionId] = value
        print("🔍 DEBUG: Stored page \(logLabel) for question \(questionId): \(value.stringKey)")
        if let pageId = currentPage?.id {
            if pageAnswers[pageId] == nil { pageAnswers[pageId] = [:] }
            pageAnswers[pageId]?[questionId] = value
            print("🔍 DEBUG: Updated pageAnswers[\(pageId)] keys: \(pageAnswers[pageId]!.keys.sorted())")
        }
        if resetRouting { resetConditionalRoutingState() }
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
            
            print("🔍 DEBUG: Loaded \(questions.count) questions for cluster: \(cluster)")
            print("🔍 DEBUG: User has \(answers.count) answers")

            let result = buildFullPath(questions: questions, answers: answers)
            var resolvedPath = result.path
            if resolvedPath.isEmpty, let first = questions.first?.id {
                resolvedPath = [first]
            }
            
            print("🔍 DEBUG: Resolved path: \(resolvedPath)")
            print("🔍 DEBUG: End reached: \(result.endReached)")

            stack = resolvedPath
            currentQuestionID = resolvedPath.last ?? questions.first?.id
            completed = result.endReached && resolvedPath.allSatisfy { answers[$0] != nil }
            
            print("🔍 DEBUG: Current question ID: \(currentQuestionID ?? "nil")")
            print("🔍 DEBUG: Completed: \(completed)")
            
            updateProgress()
        } catch {
            print("🔍 DEBUG: Error loading data: \(error)")
            errorMessage = "Errore di caricamento: \(error.localizedDescription)"
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

        // Aggiorna anche pageAnswers per la pagina corrente
        if let currentPage = self.currentPage {
            // Inizializza pageAnswers per questa pagina se non esiste
            if pageAnswers[currentPage.id] == nil {
                pageAnswers[currentPage.id] = [:]
            }
            
            // Aggiorna la risposta specifica nella pagina corrente
            pageAnswers[currentPage.id]?[question.id] = value
            
            // Salva utilizzando il nuovo sistema pageAnswers
            Task { await savePageAnswers(for: currentPage) }
        } else {
            // Fallback al sistema vecchio se non abbiamo una pagina corrente
            Task { await apiClient.saveAnswers(updatedAnswers, cluster: cluster) }
        }
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
        if usePageMode {
            guard !pages.isEmpty else {
                progress = 0
                return
            }
            if completed {
                progress = 100
            } else {
                // Per le pagine, calcoliamo il progresso basato su pagina corrente + 1 (per includere la pagina corrente)
                let completedPages = currentPageIndex + 1
                progress = min(Int(round(Double(completedPages) / Double(pages.count) * 100.0)), 99)
            }
        } else {
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
    
    private func resetConditionalRoutingState() {
        // Only reset if we're on a page that has conditional routing WITH actual rules
        // This prevents disrupting an ongoing conditional sequence
        guard let currentPageData = currentPage,
              let routing = currentPageData.conditionalRouting,
              !routing.rules.isEmpty else {
            print("🔍 DEBUG: Current page has no conditional routing rules, not resetting state")
            return
        }
        
        print("🔍 DEBUG: Resetting conditional routing state for page: \(currentPageData.id) (has \(routing.rules.count) rules)")
        conditionalPagesQueue = []
        currentConditionalIndex = 0
        print("🔍 DEBUG: ✅ Conditional routing state reset - queue is now empty")
    }
    
    private func determineStartingPageIndex() -> Int {
        // Usa motore dinamico: primo incompleto tra quelli raggiungibili
        // Se la prima pagina non è completa, partirà da 0
        let idx = PageFlowEngine.firstIncompletePageIndex(pages: pages, pageAnswers: pageAnswers)
        return min(idx, max(0, pages.count - 1))
    }
    
    private func checkQuestionnaireCompletion() -> Bool {
        PageFlowEngine.isQuestionnaireComplete(pages: pages, answers: answers, pageAnswers: pageAnswers)
    }
}

// MARK: - Inlined PageFlowEngine (dynamic, data-driven)
struct PageFlowEngine {
    static func isPageReachable(pages: [QuestionnairePage], targetIndex: Int, answers: [String: CodableValue]) -> Bool {
        guard !pages.isEmpty, targetIndex < pages.count else { return false }
        if targetIndex == 0 { return true }
        var frontier: Set<Int> = [0]
        var visited: Set<Int> = []
        while let current = frontier.popFirst() {
            if current == targetIndex { return true }
            visited.insert(current)
            let page = pages[current]
            if let routing = page.conditionalRouting {
                let nextIndices = resolveRouting(routing: routing, pages: pages, answers: answers)
                for idx in nextIndices where !visited.contains(idx) { frontier.insert(idx) }
            } else {
                let sequential = current + 1
                if sequential < pages.count { frontier.insert(sequential) }
            }
        }
        return false
    }
    private static func resolveRouting(routing: ConditionalRouting, pages: [QuestionnairePage], answers: [String: CodableValue]) -> [Int] {
        let matchingTargets: [String] = routing.rules.compactMap { rule in
            evaluateCondition(rule.condition, answers: answers) ? rule.nextPage : nil
        }
        let targets = matchingTargets.isEmpty ? [routing.defaultAction] : matchingTargets
        return targets.compactMap { id in pages.firstIndex { $0.id == id } }
    }
    private static func evaluateCondition(_ condition: RoutingCondition, answers: [String: CodableValue]) -> Bool {
        guard let value = answers[condition.questionId] else { return false }
        let userStr = value.stringKey
        let expected = condition.value
        switch condition.operatorType {
        case "==": return userStr == expected
        case "!=": return userStr != expected
        case ">", ">=", "<", "<=":
            guard let userNum = Double(userStr), let expNum = Double(expected) else { return false }
            switch condition.operatorType {
            case ">": return userNum > expNum
            case ">=": return userNum >= expNum
            case "<": return userNum < expNum
            case "<=": return userNum <= expNum
            default: return false
            }
        default: return false
        }
    }
    static func firstIncompletePageIndex(pages: [QuestionnairePage], pageAnswers: [String: [String: CodableValue]]) -> Int {
        for (idx, page) in pages.enumerated() {
            let requiredQuestions = page.questions.filter { $0.isRequired }
            if requiredQuestions.isEmpty { continue }
            let saved = pageAnswers[page.id] ?? [:]
            let answered = requiredQuestions.filter { saved[$0.id] != nil }
            if answered.count < requiredQuestions.count { return idx }
        }
        return max(0, pages.count - 1)
    }
    static func isQuestionnaireComplete(pages: [QuestionnairePage], answers: [String: CodableValue], pageAnswers: [String: [String: CodableValue]]) -> Bool {
        guard !pages.isEmpty else { return false }
        for idx in pages.indices {
            if !isPageReachable(pages: pages, targetIndex: idx, answers: answers) { continue }
            let page = pages[idx]
            let requiredQuestions = page.questions.filter { $0.isRequired }
            if requiredQuestions.isEmpty { continue }
            let saved = pageAnswers[page.id] ?? [:]
            let answered = requiredQuestions.filter { saved[$0.id] != nil }
            if answered.count < requiredQuestions.count { return false }
        }
        return true
    }
    static func cleanupUnreachablePages(pages: [QuestionnairePage], answers: [String: CodableValue], pageAnswers: [String: [String: CodableValue]], apiSave: (String) async -> Void) async -> [String: [String: CodableValue]] {
        var updated = pageAnswers
        for idx in pages.indices {
            if updated[pages[idx].id]?.isEmpty ?? true { continue }
            if !isPageReachable(pages: pages, targetIndex: idx, answers: answers) {
                updated[pages[idx].id] = [:]
                await apiSave(pages[idx].id)
            }
        }
        return updated
    }
}

extension Notification.Name {
    static let forceSaveOpenTextAnswers = Notification.Name("forceSaveOpenTextAnswers")
}
