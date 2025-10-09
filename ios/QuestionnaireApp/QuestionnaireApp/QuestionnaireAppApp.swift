import SwiftUI

@main
struct QuestionnaireAppApp: App {
    @StateObject private var listViewModel = QuestionnaireListViewModel()
    @State private var path: [QuestionnaireRoute] = []

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                QuestionnaireListView(path: $path)
                    .environmentObject(listViewModel)
                    .navigationDestination(for: QuestionnaireRoute.self) { route in
                        switch route {
                        case .questionnaire(let cluster, let title):
                            QuestionnaireFlowView(cluster: cluster, title: title)
                                .environmentObject(listViewModel)
                        }
                    }
            }
        }
    }
}
