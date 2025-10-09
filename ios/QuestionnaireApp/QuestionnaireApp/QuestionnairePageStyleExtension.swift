import SwiftUI

// Versione semplificata del sistema a pagine integrata nel file esistente
extension QuestionnaireFlowView {
    
    // Questa è una versione semplificata che raccoglie le risposte prima di salvarle
    @ViewBuilder
    private var pageBasedContent: some View {
        if viewModel.isLoading {
            ProgressView("Caricamento...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 16) {
                Text(error)
                    .foregroundColor(.red)
                Button("Torna all'elenco") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.completed {
            VStack(spacing: 24) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 16) {
                    Text("Questionario Completato!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Grazie per aver condiviso le tue informazioni.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                ProgressBarView(percentage: 100)
                
                Button("Torna all'elenco") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Mostra tutte le domande in una pagina
            pageStyleQuestions
        }
    }
    
    @ViewBuilder
    private var pageStyleQuestions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Completa tutte le domande per procedere")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Progress
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progresso: \(viewModel.progress)%")
                        .font(.headline)
                    ProgressBarView(percentage: viewModel.progress)
                }
                
                // Questions in cards
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.questions.prefix(5), id: \.id) { question in
                        QuestionCard(
                            question: question,
                            answer: viewModel.answers[question.id],
                            onAnswer: { answer in
                                viewModel.answerCurrent(with: answer)
                            }
                        )
                    }
                }
                
                // Continue button
                if viewModel.questions.count > 0 {
                    Button(action: {
                        // Per ora non fa nulla, ma potremmo implementare il salvataggio di gruppo
                    }) {
                        HStack {
                            Text("Salva Progresso")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(16)
                    }
                }
                
                Spacer(minLength: 50)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

struct QuestionCard: View {
    let question: Question
    let answer: CodableValue?
    let onAnswer: (CodableValue) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question.text)
                .font(.headline)
                .multilineTextAlignment(.leading)
            
            switch question.type {
            case .card:
                cardOptions
            case .rating:
                ratingView
            case .open:
                openQuestion
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    @ViewBuilder
    private var cardOptions: some View {
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
    
    @ViewBuilder
    private var ratingView: some View {
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
    
    @ViewBuilder
    private var openQuestion: some View {
        // Usa la QuestionView esistente per le domande aperte
        // o implementa una versione semplificata
        Text("Domanda aperta - implementazione semplificata")
            .italic()
            .foregroundColor(.secondary)
    }
}