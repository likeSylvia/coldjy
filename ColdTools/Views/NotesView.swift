import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MemoNote.pinned, order: .reverse), SortDescriptor(\MemoNote.createdAt, order: .reverse)])
    private var notes: [MemoNote]

    @State private var query: String = ""
    @State private var showEditor = false
    @State private var editing: MemoNote?

    private var filtered: [MemoNote] {
        guard !query.isEmpty else { return notes }
        let q = query.lowercased()
        return notes.filter {
            $0.title.lowercased().contains(q)
            || $0.content.lowercased().contains(q)
            || $0.tag.lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                Section {
                    EmptyStateView(icon: "note.text", text: query.isEmpty ? "还没有备忘" : "没有匹配的备忘")
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(filtered) { note in
                    Button { editing = note; showEditor = true } label: {
                        NoteRow(note: note) {
                            note.done.toggle(); try? context.save(); Haptics.tap()
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            note.pinned.toggle(); try? context.save(); Haptics.selection()
                        } label: {
                            Label(note.pinned ? "取消置顶" : "置顶", systemImage: "pin.fill")
                        }
                        .tint(.orange)
                    }
                }
                .onDelete { offsets in
                    for idx in offsets {
                        if let n = filtered[safe: idx] { context.delete(n) }
                    }
                    try? context.save(); Haptics.tap()
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "搜索标题、内容、标签")
        .overlay(alignment: .bottomTrailing) {
            Button { editing = nil; showEditor = true } label: {
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
            NoteEditorSheet(editing: editing)
        }
    }
}

private struct NoteRow: View {
    let note: MemoNote
    let onToggleDone: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggleDone) {
                Image(systemName: note.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(note.done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if note.pinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(.orange) }
                    Text(note.title)
                        .font(.body.weight(.medium))
                        .strikethrough(note.done, color: .secondary)
                        .foregroundStyle(note.done ? .secondary : .primary)
                }
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text(Fmt.dateTime(note.createdAt)).font(.caption2).foregroundStyle(.secondary)
                    if !note.tag.isEmpty {
                        Text("#\(note.tag)")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NoteEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let editing: MemoNote?

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var tag: String = ""
    @State private var hasRemind: Bool = false
    @State private var remindAt: Date = .now.addingTimeInterval(3600)
    @State private var pinned: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("标题", text: $title)
                }
                Section("内容") {
                    TextField("写点什么", text: $content, axis: .vertical)
                        .lineLimit(4...12)
                }
                Section("标签与提醒") {
                    TextField("标签（例如 工作）", text: $tag)
                    Toggle("设置提醒", isOn: $hasRemind)
                    if hasRemind {
                        DatePicker("提醒时间", selection: $remindAt)
                    }
                    Toggle("置顶", isOn: $pinned)
                }
            }
            .navigationTitle(editing == nil ? "新增备忘" : "编辑备忘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("保存") { save() }.fontWeight(.semibold).disabled(title.isEmpty && content.isEmpty) }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let n = editing else { return }
        title = n.title
        content = n.content
        tag = n.tag
        if let r = n.remindAt { hasRemind = true; remindAt = r }
        pinned = n.pinned
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = t.isEmpty ? "未命名备忘" : t
        if let n = editing {
            n.title = finalTitle
            n.content = content
            n.tag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            n.remindAt = hasRemind ? remindAt : nil
            n.pinned = pinned
        } else {
            let n = MemoNote(title: finalTitle,
                             content: content,
                             tag: tag.trimmingCharacters(in: .whitespacesAndNewlines),
                             remindAt: hasRemind ? remindAt : nil,
                             pinned: pinned)
            context.insert(n)
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
