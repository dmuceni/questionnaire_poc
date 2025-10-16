import Foundation

/// Engine per calcolare visibilità, percorso e completamento delle pagine in modo
/// completamente guidato dai dati (ConditionalRouting + risposte) senza ID hardcoded.
struct PageFlowEngine {
    /// Determina se una pagina deve essere mostrata date le risposte correnti.
    /// Si considera che una pagina è potenzialmente visitabile se esiste un cammino
    /// dalla prima pagina che la includa rispettando le regole già soddisfatte prima di essa.
    static func isPageReachable(pages: [QuestionnairePage], targetIndex: Int, answers: [String: CodableValue]) -> Bool {
        guard !pages.isEmpty, targetIndex < pages.count else { return false }
        if targetIndex == 0 { return true }
        // Simula partendo dalla prima pagina, espandendo in ampiezza tutti i rami possibili
        var frontier: Set<Int> = [0]
        var visited: Set<Int> = []
        while let current = frontier.popFirst() {
            if current == targetIndex { return true }
            visited.insert(current)
            let page = pages[current]
            if let routing = page.conditionalRouting {
                let nextIndices = resolveRouting(routing: routing, pages: pages, answers: answers)
                for idx in nextIndices { if !visited.contains(idx) { frontier.insert(idx) } }
            } else {
                let sequential = current + 1
                if sequential < pages.count { frontier.insert(sequential) }
            }
        }
        return false
    }

    /// Restituisce la lista di indici raggiungibili direttamente da un routing.
    private static func resolveRouting(routing: ConditionalRouting, pages: [QuestionnairePage], answers: [String: CodableValue]) -> [Int] {
        // Valuta tutte le regole la cui condizione è vera; se nessuna, usa defaultAction
        let matchingTargets: [String] = routing.rules.compactMap { rule in
            if evaluateCondition(rule.condition, answers: answers) { return rule.nextPage } else { return nil }
        }
        let targets: [String]
        if matchingTargets.isEmpty { targets = [routing.defaultAction] } else { targets = matchingTargets }
        return targets.compactMap { id in pages.firstIndex(where: { $0.id == id }) }
    }

    /// Valuta condizione (operatori supportati: ==, !=, >, >=, <, <=) su una risposta esistente.
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

    /// Trova il primo indice di pagina incompleta (richiede tutte le required non vuote).
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

    /// Determina completamento globale: tutte le pagine raggiungibili hanno required risposte.
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

    /// Pulisce risposte di pagine diventate non raggiungibili dopo cambi di risposta.
    static func cleanupUnreachablePages(pages: [QuestionnairePage], answers: [String: CodableValue], pageAnswers: inout [String: [String: CodableValue]], apiSave: (String) async -> Void) async {
        for idx in pages.indices {
            if pageAnswers[pages[idx].id]?.isEmpty ?? true { continue }
            if !isPageReachable(pages: pages, targetIndex: idx, answers: answers) {
                pageAnswers[pages[idx].id] = [:]
                await apiSave(pages[idx].id)
            }
        }
    }
}
