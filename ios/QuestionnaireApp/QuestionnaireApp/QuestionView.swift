import SwiftUI

struct QuestionView: View {
    let question: Question
    let answer: CodableValue?
    let onSelectRating: (Int) -> Void
    let onSelectOption: (String) -> Void
    let onUpdateOpen: (String) -> Void

    @State private var openText: String = ""
    @State private var pendingText: String = ""
    @State private var hasUnsavedChanges: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(question.text)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)

            switch question.type {
            case .rating:
                ratingView
            case .card:
                cardOptions
            case .open:
                openQuestion
            }
        }
        .onAppear(perform: syncOpenText)
        .onChange(of: answer, perform: { _ in syncOpenText() })
    }

    private var ratingView: some View {
        let scale = question.scale ?? 5
        let values = Array(1...max(scale, 1))
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button(action: { onSelectRating(value) }) {
                        Image(systemName: selectedRating != nil && selectedRating! >= value ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(selectedRating != nil && selectedRating! >= value ? .yellow : .gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            if scale == 5 {
                scaleLabels(start: "Per niente", end: "Moltissimo")
            } else if scale == 10 {
                scaleLabels(start: "Per niente probabile", end: "Estremamente probabile")
            }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            ForEach(question.options ?? []) { option in
                Button(action: { onSelectOption(option.id) }) {
                    HStack {
                        Text(option.label)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding()
                    .background(selectedOptionID == option.id ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedOptionID == option.id ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
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

    private var selectedRating: Int? {
        guard case .int(let value) = answer else { return nil }
        return value
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
}

struct QuestionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuestionView(
                question: Question(id: "q1", text: "Quanto sei soddisfatto?", type: .rating, scale: 5, options: nil, next: nil),
                answer: .int(3),
                onSelectRating: { _ in },
                onSelectOption: { _ in },
                onUpdateOpen: { _ in }
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
                    next: nil
                ),
                answer: .string("a"),
                onSelectRating: { _ in },
                onSelectOption: { _ in },
                onUpdateOpen: { _ in }
            )
            .padding()
            .previewLayout(.sizeThatFits)

            QuestionView(
                question: Question(id: "q3", text: "Scrivi un commento dettagliato sui nostri servizi", type: .open, scale: nil, options: nil, next: nil),
                answer: nil,
                onSelectRating: { _ in },
                onSelectOption: { _ in },
                onUpdateOpen: { text in print("Testo salvato: \(text)") }
            )
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
}
