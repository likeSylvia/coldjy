import SwiftUI
import SwiftData

struct WorkRecordsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkLog.createdAt, order: .reverse) private var logs: [WorkLog]

    @State private var showEditor = false
    @State private var editing: WorkLog?

    var body: some View {
        List {
            if logs.isEmpty {
                Section {
                    EmptyStateView(icon: "briefcase", text: "还没有上班记录")
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(logs) { log in
                    Button {
                        editing = log; showEditor = true
                    } label: { WorkRow(log: log) }
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
                editing = nil; showEditor = true
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
            WorkEditorSheet(editing: editing)
        }
    }
}

private struct WorkRow: View {
    let log: WorkLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.status.rawValue).font(.subheadline.weight(.semibold))
                if let s = log.startAt, let e = log.endAt {
                    Text("\(Fmt.timeOfDay(s)) - \(Fmt.timeOfDay(e))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Fmt.dateTime(log.createdAt)).font(.caption).foregroundStyle(.secondary)
            }
            if let h = log.hours {
                Text("\(String(format: "%.1f", h)) 小时").font(.caption).foregroundStyle(.secondary)
            }
            if !log.note.isEmpty {
                Text(log.note).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct WorkEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let editing: WorkLog?

    @State private var startAt: Date = .now
    @State private var endAt: Date = .now
    @State private var hasStart = false
    @State private var hasEnd = false
    @State private var status: WorkStatus = .normal
    @State private var hoursText: String = ""
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("时间") {
                    Toggle("上班时间", isOn: $hasStart)
                    if hasStart {
                        DatePicker("开始", selection: $startAt, displayedComponents: [.hourAndMinute])
                    }
                    Toggle("下班时间", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("结束", selection: $endAt, displayedComponents: [.hourAndMinute])
                    }
                }
                Section("状态") {
                    Picker("类型", selection: $status) {
                        ForEach(WorkStatus.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    HStack {
                        Text("工时")
                        TextField("小时", text: $hoursText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("备注") {
                    TextField("今天做了什么", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(editing == nil ? "新增上班" : "编辑上班")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("保存") { save() }.fontWeight(.semibold) }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let log = editing else { return }
        if let s = log.startAt { startAt = s; hasStart = true }
        if let e = log.endAt { endAt = e; hasEnd = true }
        status = log.status
        hoursText = log.hours.map { String(format: "%.1f", $0) } ?? ""
        note = log.note
    }

    private func save() {
        let h = Double(hoursText)
        if let log = editing {
            log.startAt = hasStart ? startAt : nil
            log.endAt = hasEnd ? endAt : nil
            log.statusRaw = status.rawValue
            log.hours = h
            log.note = note
        } else {
            let log = WorkLog(startAt: hasStart ? startAt : nil,
                              endAt: hasEnd ? endAt : nil,
                              status: status,
                              hours: h,
                              note: note)
            context.insert(log)
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
