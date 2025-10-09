import SwiftUI

struct QuestionView: View {
    let question: Question
    let answer: CodableValue?
    let onSelectRating: (Int) -> Void
    let onSelectOption: (String) -> Void
    let onUpdateOpen: (String) -> Void

    @State private var openText: String = ""

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
            HStack(spacing: 12) {
                ForEach(values, id: \.self) { value in
                    Button(action: { onSelectRating(value) }) {
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
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $openText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4))
                )
                .onChange(of: openText) { newValue in
                    onUpdateOpen(newValue)
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
        if case .string(let value) = answer, value != openText {
            openText = value
        }
        if answer == nil { openText = "" }
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
                question: Question(id: "q3", text: "Scrivi un commento", type: .open, scale: nil, options: nil, next: nil),
                answer: .string("Test"),
                onSelectRating: { _ in },
                onSelectOption: { _ in },
                onUpdateOpen: { _ in }
            )
            .padding()
            .previewLayout(.sizeThatFits)
        }
    }
}
