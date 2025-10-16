import SwiftUI

struct GroupedMultipleChoiceQuestionView: View {
    let question: Question
    let answer: CodableValue?
    let onUpdate: ([String]) -> Void
    
    @State private var selectedGroupId: String = ""
    @State private var searchText: String = ""
    @State private var selectedOptions: Set<String> = []
    @State private var isUpdatingFromViewModel: Bool = false
    @State private var refreshID = UUID()
    
    private var groups: [QuestionGroup] { question.groups ?? [] }
    
    private var currentGroup: QuestionGroup? {
        groups.first { $0.id == selectedGroupId } ?? groups.first
    }
    
    private var filteredOptions: [QuestionOption] {
        guard let group = currentGroup else { return [] }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return group.options }
        return group.options.filter { $0.label.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if question.searchEnabled == true {
                searchBar
            }
            
            if groups.count > 1 {
                groupTabs
            }
            
            optionsList
            
            if !selectedOptions.isEmpty {
                selectionSummary
            }
        }
        .onAppear { initialSync() }
        .onChange(of: answer) { _ in syncAnswerFromViewModel() }
        .onChange(of: selectedGroupId) { _ in refreshID = UUID() }
    }
    
    private var searchBar: some View {
        TextField("Cerca...", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .onChange(of: searchText) { _ in refreshID = UUID() }
    }
    
    private var groupTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groups) { group in
                    Button(action: { withAnimation { selectedGroupId = group.id } }) {
                        Text(group.label)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedGroupId == group.id ? Color.accentColor : Color(.systemGray5))
                            )
                            .foregroundColor(selectedGroupId == group.id ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var optionsList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(filteredOptions) { option in
                MultipleChoiceOptionView(
                    option: option,
                    selectedOptions: Binding(
                        get: { selectedOptions },
                        set: { _ in }
                    ),
                    onToggle: { toggleOption(option.id) }
                )
                .id("\(option.id)-\(refreshID)")
            }
        }
        .animation(.easeInOut, value: filteredOptions.map { $0.id })
    }
    
    private var selectionSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("\(selectedOptions.count) selezioni")
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
            Button("Pulisci") { clearSelections() }
                .font(.footnote)
        }
        .padding(.top, 4)
    }
    
    private func initialSync() {
        if let first = groups.first { selectedGroupId = first.id }
        syncAnswerFromViewModel()
    }
    
    private func syncAnswerFromViewModel() {
        guard question.type == .multipleChoiceGrouped else { return }
        isUpdatingFromViewModel = true
        if case .stringArray(let array) = answer {
            let newSet = Set(array)
            if selectedOptions != newSet {
                selectedOptions = newSet
                refreshID = UUID()
            }
        } else {
            if !selectedOptions.isEmpty { selectedOptions = [] }
        }
        isUpdatingFromViewModel = false
    }
    
    private func toggleOption(_ optionId: String) {
        guard !isUpdatingFromViewModel else { return }
        if let max = question.maxSelections, selectedOptions.count >= max, !selectedOptions.contains(optionId) {
            // superato limite e si tenta di aggiungere nuova
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        var newSet = selectedOptions
        if newSet.contains(optionId) { newSet.remove(optionId) } else { newSet.insert(optionId) }
        selectedOptions = newSet
        refreshID = UUID()
        onUpdate(Array(newSet))
    }
    
    private func clearSelections() {
        selectedOptions = []
        refreshID = UUID()
        onUpdate([])
    }
}

struct GroupedMultipleChoiceQuestionView_Previews: PreviewProvider {
    static var previews: some View {
        let groups = [
            QuestionGroup(id: "serie_a", label: "Serie A", options: [
                QuestionOption(id: "juventus", label: "Juventus"),
                QuestionOption(id: "inter", label: "Inter"),
                QuestionOption(id: "milan", label: "Milan")
            ]),
            QuestionGroup(id: "serie_b", label: "Serie B", options: [
                QuestionOption(id: "parma", label: "Parma"),
                QuestionOption(id: "palermo", label: "Palermo")
            ])
        ]
        let q = Question(id: "calcio_squadre_preferite", text: "Seleziona le tue squadre preferite", type: .multipleChoiceGrouped, scale: nil, options: nil, next: nil, required: true, groups: groups, searchEnabled: true)
        GroupedMultipleChoiceQuestionView(question: q, answer: .stringArray(["juventus"]) , onUpdate: { _ in })
            .padding()
            .previewLayout(.sizeThatFits)
    }
}