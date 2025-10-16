import SwiftUI
import UIKit

struct QuestionView: View {
    let question: Question
    let answer: CodableValue?
    let onSelectRating: (Int) -> Void
    let onSelectOption: (String) -> Void
    let onUpdateOpen: (String) -> Void
    let onSelectMultipleChoice: ([String]) -> Void
    // Reuse same closure for grouped multiple choice

    @State private var openText: String = ""
    @State private var pendingText: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @State private var sliderValue: Double = 0
    @State private var selectedMultipleOptions: Set<String> = []
    @State private var isUpdatingFromViewModel: Bool = false
    @State private var refreshID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text(question.text)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
                
                if question.isRequired {
                    Text("*")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }

            switch question.type {
            case .rating:
                ratingView
            case .card:
                cardOptions
            case .open:
                openQuestion
            case .multipleChoice:
                multipleChoiceOptions
            case .multipleChoiceGrouped:
                groupedMultipleChoiceView
            }
        }
        .onAppear {
            syncOpenText()
            syncRatingValue()
            syncMultipleChoiceSelection()
        }
        .onChange(of: answer) { newAnswer in
            isUpdatingFromViewModel = true
            syncOpenText()
            syncRatingValue()
            syncMultipleChoiceSelection()
            refreshID = UUID() // Force UI refresh
            isUpdatingFromViewModel = false
        }
        .onChange(of: question.id) { _ in
            syncOpenText()
            syncRatingValue()
            syncMultipleChoiceSelection()
            refreshID = UUID() // Force UI refresh
        }
        .onReceive(NotificationCenter.default.publisher(for: .forceSaveOpenTextAnswers)) { notification in
            // If this notification is for our current page and we have unsaved text, auto-save it
            if question.type == .open && hasUnsavedChanges && !pendingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                openText = pendingText
                onUpdateOpen(pendingText)
                hasUnsavedChanges = false
                print("🔍 DEBUG: Auto-saved pending text for question \(question.id): \(pendingText)")
            }
        }
    }

    private var ratingView: some View {
        let values = ratingValues
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                scaleAdjustButton(symbol: "−", isDisabled: currentRating <= minRatingValue) {
                    changeRating(by: -1)
                }

                VStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { sliderValue },
                            set: { newValue in
                                guard !isUpdatingFromViewModel else { return }
                                let roundedValue = Int(newValue.rounded())
                                if currentRating != roundedValue {
                                    sliderValue = newValue
                                    onSelectRating(roundedValue)
                                }
                            }
                        ),
                        in: Double(minRatingValue)...Double(maxRatingValue),
                        step: 1
                    )
                    .tint(.accentColor)
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 0) {
                        ForEach(values, id: \.self) { value in
                            Text("\(value)")
                                .font(.footnote)
                                .fontWeight(currentRating == value ? .semibold : .regular)
                                .foregroundColor(currentRating == value ? .accentColor : .secondary)
                            if value != values.last {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                scaleAdjustButton(symbol: "+", isDisabled: currentRating >= maxRatingValue) {
                    changeRating(by: 1)
                }
            }

            if maxRatingValue == 5 {
                scaleLabels(start: "Per niente", end: "Moltissimo")
            } else if maxRatingValue == 10 {
                scaleLabels(start: "Per niente probabile", end: "Estremamente probabile")
            }
        }
    }

    private func scaleAdjustButton(symbol: String, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundColor(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isDisabled ? Color(.systemGray4) : Color.accentColor, lineWidth: isDisabled ? 1 : 2)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(isDisabled ? Color(.systemGray3) : .primary)
        .opacity(isDisabled ? 0.6 : 1.0)
        .disabled(isDisabled)
    }

    private func scaleLabels(start: String, end: String) -> some View {
        HStack {
            Text(start)
            Spacer()
            Text(end)
        }
        .font(.footnote)
        .foregroundColor(.secondary)
    }

    private var cardOptions: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(question.options ?? []) { option in
                FastCardOptionView(
                    option: option,
                    isSelected: selectedOptionID == option.id,
                    onTap: { onSelectOption(option.id) }
                )
            }
        }
    }

    private var openQuestion: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextEditor(text: $pendingText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hasUnsavedChanges ? Color.accentColor : Color(.systemGray4), lineWidth: hasUnsavedChanges ? 2 : 1)
                )
                .onChange(of: pendingText) { newValue in
                    hasUnsavedChanges = (newValue != openText)
                }
            
            if hasUnsavedChanges || pendingText.isEmpty {
                HStack {
                    if hasUnsavedChanges {
                        Button("Annulla") {
                            pendingText = openText
                            hasUnsavedChanges = false
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Conferma") {
                        openText = pendingText
                        onUpdateOpen(pendingText)
                        hasUnsavedChanges = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pendingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            if !hasUnsavedChanges && !openText.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Risposta salvata")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var multipleChoiceOptions: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(question.options ?? []) { option in
                MultipleChoiceOptionView(
                    option: option,
                    selectedOptions: $selectedMultipleOptions,
                    onToggle: { 
                        print("🔍 DEBUG: Tapped option \(option.id)")
                        toggleMultipleChoiceOption(option.id)
                    }
                )
                .id("\(option.id)-\(refreshID)") // Forzare il re-rendering
            }
            
            if !selectedMultipleOptions.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.footnote)
                    Text("\(selectedMultipleOptions.count) opzioni selezionate")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .id(refreshID) // ID per l'intera sezione
    }

    private var groupedMultipleChoiceView: some View {
        GroupedMultipleChoiceQuestionView(
            question: question,
            answer: answer,
            onUpdate: { selected in
                onSelectMultipleChoice(selected)
            }
        )
    }

    private var minRatingValue: Int {
        if let scale = question.scale, scale >= 10 {
            return 0
        }
        return 1
    }

    private var maxRatingValue: Int {
        let scale = question.scale ?? 5
        return max(scale, minRatingValue)
    }

    private var ratingValues: [Int] {
        guard maxRatingValue >= minRatingValue else { return [] }
        return Array(minRatingValue...maxRatingValue)
    }

    private var currentRating: Int {
        let value = Int(sliderValue.rounded())
        return min(max(value, minRatingValue), maxRatingValue)
    }

    private var selectedOptionID: String? {
        guard case .string(let value) = answer else { return nil }
        return value
    }

    private func syncOpenText() {
        guard question.type == .open else { return }
        if case .string(let value) = answer {
            if value != openText {
                openText = value
                pendingText = value
                hasUnsavedChanges = false
            }
        } else if answer == nil {
            openText = ""
            pendingText = ""
            hasUnsavedChanges = false
        }
    }

    private func changeRating(by delta: Int) {
        guard !isUpdatingFromViewModel else { return }
        let newValue = min(max(currentRating + delta, minRatingValue), maxRatingValue)
        if newValue != currentRating {
            sliderValue = Double(newValue)
            onSelectRating(newValue)
        }
    }

    private func syncRatingValue() {
        guard question.type == .rating else { return }
        let range = Double(minRatingValue)...Double(maxRatingValue)
        let target: Double
        if case .int(let value) = answer {
            target = Double(value)
        } else {
            target = range.lowerBound
        }
        sliderValue = min(max(target, range.lowerBound), range.upperBound)
    }
    
    private func syncMultipleChoiceSelection() {
        guard question.type == .multipleChoice else { return }
        
        let newSelectedOptions: Set<String>
        if case .stringArray(let selectedOptions) = answer {
            newSelectedOptions = Set(selectedOptions)
        } else {
            newSelectedOptions = []
        }
        
        // Solo aggiorna se c'è una differenza reale
        if selectedMultipleOptions != newSelectedOptions {
            print("🔍 DEBUG: Syncing multiple choice - Old: \(selectedMultipleOptions), New: \(newSelectedOptions)")
            selectedMultipleOptions = newSelectedOptions
            refreshID = UUID() // Force UI refresh
        }
    }
    
    private func toggleMultipleChoiceOption(_ optionId: String) {
        // Skip if we're updating from ViewModel to avoid loops
        guard !isUpdatingFromViewModel else { return }
        
        print("🔍 DEBUG: Toggle option \(optionId) - Current selected: \(selectedMultipleOptions)")
        
        // Immediate update for UI responsiveness
        var newSelectedOptions = selectedMultipleOptions
        if newSelectedOptions.contains(optionId) {
            newSelectedOptions.remove(optionId)
            print("🔍 DEBUG: Removing option \(optionId)")
        } else {
            newSelectedOptions.insert(optionId)
            print("🔍 DEBUG: Adding option \(optionId)")
        }
        
        // Update state immediately for UI
        selectedMultipleOptions = newSelectedOptions
        print("🔍 DEBUG: Updated UI state to: \(selectedMultipleOptions)")
        
        // Force UI refresh
        refreshID = UUID()
        
        // Send update to parent
        let optionsArray = Array(newSelectedOptions)
        onSelectMultipleChoice(optionsArray)
        
        print("🔍 DEBUG: UI Toggle - Selected options: \(optionsArray)")
    }
}

// Ultra-fast optimized views
struct FastCardOptionView: View {
    let option: QuestionOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(option.label)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2 : 0)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

struct MultipleChoiceOptionView: View {
    let option: QuestionOption
    @Binding var selectedOptions: Set<String>
    let onToggle: () -> Void
    
    private var isSelected: Bool {
        selectedOptions.contains(option.id)
    }
    
    var body: some View {
        Button(action: {
            print("🔍 DEBUG: MultipleChoiceOptionView button tapped for \(option.id)")
            onToggle()
        }) {
            optionContent
        }
        .buttonStyle(PlainButtonStyle())
        .onChange(of: selectedOptions) { _ in
            print("🔍 DEBUG: selectedOptions changed - \(option.id) is now \(isSelected ? "selected" : "not selected")")
        }
    }
    
    private var optionContent: some View {
        HStack(spacing: 12) {
            checkboxIcon
            optionText
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(optionBackground)
        .overlay(optionBorder)
    }
    
    private var checkboxIcon: some View {
        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .font(.title3)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var optionText: some View {
        Text(option.label)
            .font(.body)
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
    }
    
    private var optionBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var optionBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct FastMultipleChoiceOptionView: View {
    let option: QuestionOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            print("🔍 DEBUG: FastMultipleChoiceOptionView button pressed for \(option.id), currently isSelected: \(isSelected)")
            onTap()
        }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? Color.accentColor : Color(.systemGray3))
                
                Text(option.label)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(isSelected ? Color.accentColor.opacity(0.05) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .onAppear {
            print("🔍 DEBUG: FastMultipleChoiceOptionView appeared for \(option.id), isSelected: \(isSelected)")
        }
        .onChange(of: isSelected) { newValue in
            print("🔍 DEBUG: FastMultipleChoiceOptionView isSelected changed for \(option.id): \(newValue)")
        }
    }
}

struct QuestionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            QuestionView(
                question: Question(id: "q1", text: "Quanto sei soddisfatto?", type: .rating, scale: 5, options: nil, next: nil, required: true),
                answer: .int(3),
                onSelectRating: { _ in },
                onSelectOption: { _ in },
                onUpdateOpen: { _ in },
                onSelectMultipleChoice: { _ in }
            )
            .padding()
            .previewLayout(.sizeThatFits)

            QuestionView(
                question: Question(
                    id: "q2",
                    text: "Seleziona un'opzione",
                    type: .card,
                    scale: nil,
                    options: [QuestionOption(id: "a", label: "Opzione A"), QuestionOption(id: "b", label: "Opzione B")],
                    next: nil,
                    required: true
                ),
                answer: .string("a"),
                onSelectRating: { _ in },
                onSelectOption: { _ in },
                onUpdateOpen: { _ in },
                onSelectMultipleChoice: { _ in }
            )
            .padding()
            .previewLayout(.sizeThatFits)

            QuestionView(
                question: Question(id: "q3", text: "Scrivi un commento dettagliato sui nostri servizi", type: .open, scale: nil, options: nil, next: nil, required: false),
                answer: nil,
                onSelectRating: { _ in },
                onSelectOption: { _ in },
                onUpdateOpen: { text in print("Testo salvato: \(text)") },
                onSelectMultipleChoice: { _ in }
            )
            .padding()
            .previewLayout(.sizeThatFits)
            
            QuestionView(
                question: Question(
                    id: "q4",
                    text: "Seleziona tutte le opzioni che si applicano",
                    type: .multipleChoice,
                    scale: nil,
                    options: [
                        QuestionOption(id: "option1", label: "Prima opzione"),
                        QuestionOption(id: "option2", label: "Seconda opzione"),
                        QuestionOption(id: "option3", label: "Terza opzione"),
                        QuestionOption(id: "option4", label: "Quarta opzione")
                    ],
                    next: nil,
                    required: true
                ),
                answer: .stringArray(["option1", "option3"]),
                onSelectRating: { _ in },
                onSelectOption: { _ in },
                onUpdateOpen: { _ in },
                onSelectMultipleChoice: { selectedOptions in print("Opzioni selezionate: \(selectedOptions)") }
            )
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
}

struct RoundedCorners: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
