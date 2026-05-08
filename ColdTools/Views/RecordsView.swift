import SwiftUI
import SwiftData

enum RecordTab: String, CaseIterable, Identifiable {
    case health = "健康"
    case work = "上班"
    case notes = "备忘"
    case report = "周报"

    var id: String { rawValue }
}

struct RecordsView: View {
    @State private var tab: RecordTab = .health

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(RecordTab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onChange(of: tab) { _, _ in Haptics.selection() }

                paneContent
            }
            .navigationTitle("记录")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private var paneContent: some View {
        switch tab {
        case .health: HealthRecordsView()
        case .work: WorkRecordsView()
        case .notes: NotesView()
        case .report: WeeklyReportView()
        }
    }
}
