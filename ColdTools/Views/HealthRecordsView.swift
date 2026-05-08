import SwiftUI
import SwiftData

struct HealthRecordsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HealthLog.createdAt, order: .reverse) private var logs: [HealthLog]

    @State private var showEditor = false
    @State private var editing: HealthLog?

    var body: some View {
        List {
            if logs.isEmpty {
                Section {
                    EmptyStateView(icon: "heart.text.square", text: "还没有健康记录")
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(logs) { log in
                    Button {
                        editing = log; showEditor = true
                    } label: {
                        HealthRow(log: log)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for idx in offsets { context.delete(logs[idx]) }
                    try? context.save(); Haptics.tap()
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .bottomTrailing) {
            Button {
                editing = nil
                showEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(radius: 6, y: 3)
            }
            .padding(24)
        }
        .sheet(isPresented: $showEditor) {
            HealthEditorSheet(editing: editing)
        }
    }
}

private struct HealthRow: View {
    let log: HealthLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.mood.emoji)
                Text(log.mood.rawValue)
                Text("·")
                Text(log.energy.rawValue)
                Spacer()
                Text(Fmt.dateTime(log.createdAt))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .font(.subheadline)

            HStack(spacing: 10) {
                if let w = log.weight { Label("\(String(format: "%.1f", w)) kg", systemImage: "scalemass") }
                if let s = log.sleepHours { Label("\(String(format: "%.1f", s)) h", systemImage: "bed.double") }
            }
            .font(.caption).foregroundStyle(.secondary)

            if !log.bodyNote.isEmpty {
                Text(log.bodyNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HealthEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let editing: HealthLog?

    @State private var weightText: String = ""
    @State private var sleepText: String = ""
    @State private var mood: Mood = .calm
    @State private var energy: Energy = .normal
    @State private var bodyNote: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("身体") {
                    HStack {
                        Text("体重")
                        TextField("kg", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("睡眠")
                        TextField("小时", text: $sleepText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("状态") {
                    Picker("心情", selection: $mood) {
                        ForEach(Mood.allCases) { m in
                            Text("\(m.emoji) \(m.rawValue)").tag(m)
                        }
                    }
                    Picker("精力", selection: $energy) {
                        ForEach(Energy.allCases) { e in
                            Text(e.rawValue).tag(e)
                        }
                    }
                }
                Section("身体情况") {
                    TextField("咳嗽、运动、饮食...", text: $bodyNote, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(editing == nil ? "新增健康" : "编辑健康")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }.fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }.fontWeight(.semibold)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let log = editing else { return }
        weightText = log.weight.map { String(format: "%.1f", $0) } ?? ""
        sleepText = log.sleepHours.map { String(format: "%.1f", $0) } ?? ""
        mood = log.mood
        energy = log.energy
        bodyNote = log.bodyNote
    }

    private func save() {
        let w = Double(weightText)
        let s = Double(sleepText)
        if let log = editing {
            log.weight = w
            log.sleepHours = s
            log.moodRaw = mood.rawValue
            log.energyRaw = energy.rawValue
            log.bodyNote = bodyNote
        } else {
            let log = HealthLog(weight: w, sleepHours: s, mood: mood, energy: energy, bodyNote: bodyNote)
            context.insert(log)
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
