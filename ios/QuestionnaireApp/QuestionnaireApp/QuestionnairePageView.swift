import SwiftUI

struct QuestionnairePageView: View {
    let page: QuestionnairePage
    let savedAnswers: [String: CodableValue]
    let onContinue: ([String: CodableValue]) -> Void
    let onBack: () -> Void
    
    @State private var currentAnswers: [String: CodableValue] = [:]
    @State private var showValidationErrors = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    if let title = page.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    if let description = page.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Questions
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(visibleQuestions, id: \.id) { question in
                        QuestionCard(
                            question: question,
                            answer: currentAnswers[question.id],
                            showError: showValidationErrors && question.required && currentAnswers[question.id] == nil,
                            onAnswer: { answer in
                                currentAnswers[question.id] = answer
                                showValidationErrors = false
                            }
                        )
                    }
                }
                
                // Continue Button
                VStack(spacing: 16) {
                    Button(action: handleContinue) {
                        HStack {
                            Text("Continua")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(16)
                    }
                    
                    if showValidationErrors {
                        Text("Completa tutte le domande obbligatorie per continuare")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Indietro")
                    }
                }
            }
        }
        .onAppear {
            // Initialize with saved answers
            currentAnswers = savedAnswers
        }
    }
    
    private var visibleQuestions: [PageQuestion] {
        page.questions.filter { question in
            guard let showIf = question.showIf else { return true }
            return currentAnswers[showIf.questionId]?.stringValue == showIf.value
        }
    }
    
    private var requiredQuestions: [PageQuestion] {
        visibleQuestions.filter { $0.required }
    }
    
    private var isValid: Bool {
        requiredQuestions.allSatisfy { question in
            currentAnswers[question.id] != nil
        }
    }
    
    private func handleContinue() {
        print("🔍 QuestionnairePageView.handleContinue: isValid=\(isValid), currentAnswers=\(currentAnswers)")
        if isValid {
            onContinue(currentAnswers)
        } else {
            showValidationErrors = true
        }
    }
}

struct QuestionCard: View {
    let question: PageQuestion
    let answer: CodableValue?
    let showError: Bool
    let onAnswer: (CodableValue) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question header
            HStack {
                Text(question.text)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if question.required {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.headline)
                }
            }
            
            // Question content
            switch question.type {
            case .card:
                CardQuestionView(
                    question: question,
                    answer: answer,
                    onAnswer: onAnswer
                )
            case .rating:
                RatingQuestionView(
                    question: question,
                    answer: answer,
                    onAnswer: onAnswer
                )
            case .open:
                OpenQuestionView(
                    question: question,
                    answer: answer,
                    onAnswer: onAnswer
                )
            }
            
            if showError {
                Text("Questa domanda è obbligatoria")
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(showError ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Question Type Views

struct CardQuestionView: View {
    let question: PageQuestion
    let answer: CodableValue?
    let onAnswer: (CodableValue) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(question.options ?? []) { option in
                Button(action: { onAnswer(.string(option.id)) }) {
                    HStack {
                        Text(option.label)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if selectedOptionID == option.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                    .background(selectedOptionID == option.id ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedOptionID == option.id ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var selectedOptionID: String? {
        guard case .string(let value) = answer else { return nil }
        return value
    }
}

struct RatingQuestionView: View {
    let question: PageQuestion
    let answer: CodableValue?
    let onAnswer: (CodableValue) -> Void
    
    var body: some View {
        let scale = question.scale ?? 5
        let values = Array(1...max(scale, 1))
        
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ForEach(values, id: \.self) { value in
                    Button(action: { onAnswer(.int(value)) }) {
                        Text("\(value)")
                            .font(.headline)
                            .foregroundColor(selectedRating == value ? .white : .primary)
                            .frame(width: 48, height: 48)
                            .background(selectedRating == value ? Color.accentColor : Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if scale == 5 {
                HStack {
                    Text("Per niente")
                    Spacer()
                    Text("Moltissimo")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var selectedRating: Int? {
        guard case .int(let value) = answer else { return nil }
        return value
    }
}

struct OpenQuestionView: View {
    let question: PageQuestion
    let answer: CodableValue?
    let onAnswer: (CodableValue) -> Void
    
    @State private var text: String = ""
    @State private var pendingText: String = ""
    @State private var hasChanges: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $pendingText)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hasChanges ? Color.accentColor : Color(.systemGray4), lineWidth: hasChanges ? 2 : 1)
                )
                .onChange(of: pendingText) { _ in
                    hasChanges = (pendingText != text)
                }
            
            if hasChanges {
                HStack {
                    Button("Annulla") {
                        pendingText = text
                        hasChanges = false
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Salva") {
                        text = pendingText
                        onAnswer(.string(pendingText))
                        hasChanges = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            if case .string(let value) = answer {
                text = value
                pendingText = value
            }
        }
    }
}

// MARK: - Extensions

extension CodableValue {
    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        }
    }
}

struct QuestionnairePageView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            QuestionnairePageView(
                page: QuestionnairePage(
                    id: "page_1",
                    title: "Informazioni sulla Casa",
                    description: "Iniziamo con alcune domande sulla tua abitazione",
                    questions: [
                        PageQuestion(
                            id: "q1",
                            text: "Vivi in un immobile di tua proprietà o sei in affitto?",
                            type: .card,
                            required: true,
                            multiple: nil,
                            scale: nil,
                            options: [
                                QuestionOption(id: "proprieta", label: "Di proprietà"),
                                QuestionOption(id: "affitto", label: "In affitto")
                            ],
                            showIf: nil
                        ),
                        PageQuestion(
                            id: "q2",
                            text: "Da quanti anni vivi nella tua abitazione?",
                            type: .open,
                            required: true,
                            multiple: nil,
                            scale: nil,
                            options: nil,
                            showIf: nil
                        )
                    ],
                    nextPage: nil
                ),
                savedAnswers: [:],
                onContinue: { _ in },
                onBack: { }
            )
        }
    }
}