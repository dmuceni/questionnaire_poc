import SwiftUI
import UIKit

struct QuestionView: View {
    let question: Question
    let answer: CodableValue?
    let onSelectRating: (Int) -> Void
    let onSelectOption: (String) -> Void
    let onUpdateOpen: (String) -> Void

    @State private var openText: String = ""
    @State private var pendingText: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @State private var sliderValue: Double = 0

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
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemGray6))
        )
        .overlay(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.835, blue: 0.310),
                    Color(red: 1.0, green: 0.718, blue: 0.302),
                    Color(red: 0.259, green: 0.647, blue: 0.961),
                    Color(red: 0.098, green: 0.463, blue: 0.824)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 10)
            .clipShape(RoundedCorners(radius: 24, corners: [.topLeft, .topRight])),
            alignment: .top
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
        .onAppear {
            syncOpenText()
            syncRatingValue()
        }
        .onChange(of: answer) { _ in
            syncOpenText()
            syncRatingValue()
        }
        .onChange(of: question.id) { _ in
            syncOpenText()
            syncRatingValue()
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
                                sliderValue = newValue
                                onSelectRating(Int(newValue.rounded()))
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
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundColor(isDisabled ? Color(.systemGray3) : .primary)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isDisabled ? Color(.systemGray4) : Color.accentColor, lineWidth: isDisabled ? 1 : 2)
        )
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
        let newValue = min(max(currentRating + delta, minRatingValue), maxRatingValue)
        sliderValue = Double(newValue)
        onSelectRating(newValue)
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
