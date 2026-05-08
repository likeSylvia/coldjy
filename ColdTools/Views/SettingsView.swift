import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(LockStore.self) private var lock
    @Query private var settingsList: [AppSettings]
    @Query private var allSmokes: [SmokingLog]
    @Query private var allCravings: [CravingLog]
    @Query private var allWaters: [WaterLog]
    @Query private var allHealths: [HealthLog]
    @Query private var allWorks: [WorkLog]
    @Query private var allNotes: [MemoNote]

    @State private var showPasscodeSheet = false
    @State private var showClearConfirm = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var exportPassword: String = ""
    @State private var showImportSheet = false
    @State private var importPassword: String = ""
    @State private var importURL: URL?
    @State private var showImportPicker = false
    @State private var importMessage: String?

    private var settings: AppSettings { settingsList.first ?? AppSettingsStore.current(in: context) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("解锁方式", selection: Binding(get: { settings.lockMode }, set: { setLockMode($0) })) {
                        ForEach(availableLockModes, id: \.self) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    if needsPasscode {
                        Button {
                            showPasscodeSheet = true
                        } label: {
                            HStack {
                                Label(settings.passcodeHash == nil ? "设置访问密码" : "修改访问密码", systemImage: "key.fill")
                                Spacer()
                                if settings.passcodeHash != nil {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    Button {
                        lock.lockNow(settings: settings)
                    } label: {
                        Label("立即锁定", systemImage: "lock.fill")
                    }
                    .disabled(settings.lockMode == .off)
                } header: {
                    Text("隐私锁")
                } footer: {
                    if !LockStore.isBiometryAvailable {
                        Text("当前设备未检测到 Face ID 或 Touch ID，将仅提供密码锁。")
                    }
                }

                Section("外观") {
                    Toggle("跟随系统", isOn: Binding(get: { settings.useSystemAppearance }, set: { settings.useSystemAppearance = $0; try? context.save() }))
                    if !settings.useSystemAppearance {
                        Toggle("深色模式", isOn: Binding(get: { settings.forceDarkMode }, set: { settings.forceDarkMode = $0; try? context.save() }))
                    }
                }

                Section("数据概览") {
                    overviewRow(icon: "nosign", title: "吸烟", count: allSmokes.count, tint: .red)
                    overviewRow(icon: "hand.raised", title: "忍住", count: allCravings.count, tint: .orange)
                    overviewRow(icon: "drop.fill", title: "喝水", count: allWaters.count, tint: .blue)
                    overviewRow(icon: "heart.text.square", title: "健康", count: allHealths.count, tint: .pink)
                    overviewRow(icon: "briefcase", title: "上班", count: allWorks.count, tint: .purple)
                    overviewRow(icon: "note.text", title: "备忘", count: allNotes.count, tint: .green)
                }

                Section("数据备份") {
                    Button {
                        showExportSheet = true
                    } label: {
                        Label("加密导出备份", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImportPicker = true
                    } label: {
                        Label("导入备份", systemImage: "square.and.arrow.down")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("清空全部数据", systemImage: "trash")
                    }
                } footer: {
                    Text("清空后不可恢复，建议先导出加密备份。")
                }

                Section("关于") {
                    HStack {
                        Text("版本"); Spacer()
                        Text(appVersionString).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(settings.useSystemAppearance ? nil : (settings.forceDarkMode ? .dark : .light))
            .alert("清空全部数据？", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) { clearAll() }
            } message: {
                Text("此操作不可恢复。")
            }
            .sheet(isPresented: $showPasscodeSheet) {
                PasscodeSetupSheet()
            }
            .sheet(isPresented: $showExportSheet) {
                ExportSheet(password: $exportPassword) { runExport() }
                    .presentationDetents([.medium])
            }
            .fileImporter(isPresented: $showImportPicker,
                          allowedContentTypes: [.json, UTType(filenameExtension: "txbak") ?? .data],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let first = urls.first {
                    importURL = first
                    showImportSheet = true
                }
            }
            .sheet(isPresented: $showImportSheet) {
                ImportSheet(password: $importPassword, message: $importMessage) {
                    runImport()
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: Binding(get: { exportURL != nil }, set: { if !$0 { exportURL = nil } })) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private var availableLockModes: [LockMode] {
        if LockStore.isBiometryAvailable {
            return LockMode.allCases
        }
        return [.off, .passcode]
    }

    private var needsPasscode: Bool {
        settings.lockMode == .passcode || settings.lockMode == .both
    }

    private var appVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func overviewRow(icon: String, title: String, count: Int, tint: Color) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundStyle(tint)
            Spacer()
            Text("\(count) 条").foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func setLockMode(_ mode: LockMode) {
        if mode == .off {
            settings.lockModeRaw = LockMode.off.rawValue
            try? context.save()
            return
        }
        if mode == .biometric {
            if !LockStore.isBiometryAvailable {
                Haptics.error()
                return
            }
            settings.lockModeRaw = LockMode.biometric.rawValue
            try? context.save()
            return
        }
        // passcode / both 必须先有密码
        if settings.passcodeHash == nil {
            showPasscodeSheet = true
            // 密码设置完成后, PasscodeSetupSheet 会根据 biometry 可用性把 lockMode 切到 both/passcode
            return
        }
        settings.lockModeRaw = mode.rawValue
        try? context.save()
    }

    private func clearAll() {
        for s in allSmokes { context.delete(s) }
        for c in allCravings { context.delete(c) }
        for w in allWaters { context.delete(w) }
        for h in allHealths { context.delete(h) }
        for w in allWorks { context.delete(w) }
        for n in allNotes { context.delete(n) }
        try? context.save()
        Haptics.warning()
    }

    // MARK: - Backup

    private func runExport() {
        guard exportPassword.count >= 6 else {
            Haptics.error()
            return
        }
        let payload = BackupSnapshot(
            smokes: allSmokes.map(BackupSnapshot.SmokeRow.init),
            cravings: allCravings.map(BackupSnapshot.CravingRow.init),
            waters: allWaters.map(BackupSnapshot.WaterRow.init),
            healths: allHealths.map(BackupSnapshot.HealthRow.init),
            works: allWorks.map(BackupSnapshot.WorkRow.init),
            notes: allNotes.map(BackupSnapshot.NoteRow.init),
            settings: BackupSnapshot.SettingsRow(from: settings)
        )
        do {
            let plain = try JSONEncoder().encode(payload)
            let encrypted = try BackupCrypto.encrypt(plaintext: plain, password: exportPassword)
            let jsonData = try JSONEncoder().encode(encrypted)
            let name = "cold-tools-\(DateKey.day(.now)).txbak"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try jsonData.write(to: url)
            exportURL = url
            showExportSheet = false
            exportPassword = ""
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }

    private func runImport() {
        guard let url = importURL else { return }
        importMessage = nil
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let raw = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(EncryptedBackupPayload.self, from: raw)
            let plain = try BackupCrypto.decrypt(payload: payload, password: importPassword)
            let snapshot = try JSONDecoder().decode(BackupSnapshot.self, from: plain)
            apply(snapshot: snapshot)
            showImportSheet = false
            importPassword = ""
            importURL = nil
            Haptics.success()
        } catch {
            importMessage = "导入失败：密码错误或文件损坏"
            Haptics.error()
        }
    }

    private func apply(snapshot: BackupSnapshot) {
        // 简单策略:按 id 去重合并
        let existingIds = Set(allSmokes.map(\.id))
        for row in snapshot.smokes where !existingIds.contains(row.id) {
            context.insert(SmokingLog(id: row.id, at: row.at, trigger: row.trigger, note: row.note))
        }
        let existingCraving = Set(allCravings.map(\.id))
        for row in snapshot.cravings where !existingCraving.contains(row.id) {
            context.insert(CravingLog(id: row.id, at: row.at, trigger: row.trigger, intensity: row.intensity, resisted: row.resisted, note: row.note))
        }
        let existingWater = Set(allWaters.map(\.id))
        for row in snapshot.waters where !existingWater.contains(row.id) {
            context.insert(WaterLog(id: row.id, at: row.at, amount: row.amount))
        }
        let existingHealth = Set(allHealths.map(\.id))
        for row in snapshot.healths where !existingHealth.contains(row.id) {
            context.insert(HealthLog(id: row.id, createdAt: row.createdAt, weight: row.weight, sleepHours: row.sleepHours, mood: Mood(rawValue: row.moodRaw) ?? .calm, energy: Energy(rawValue: row.energyRaw) ?? .normal, bodyNote: row.bodyNote))
        }
        let existingWork = Set(allWorks.map(\.id))
        for row in snapshot.works where !existingWork.contains(row.id) {
            context.insert(WorkLog(id: row.id, createdAt: row.createdAt, startAt: row.startAt, endAt: row.endAt, status: WorkStatus(rawValue: row.statusRaw) ?? .normal, hours: row.hours, note: row.note))
        }
        let existingNote = Set(allNotes.map(\.id))
        for row in snapshot.notes where !existingNote.contains(row.id) {
            context.insert(MemoNote(id: row.id, createdAt: row.createdAt, title: row.title, content: row.content, tag: row.tag, remindAt: row.remindAt, pinned: row.pinned, done: row.done))
        }
        // 设置
        settings.baselineCigs = snapshot.settings.baselineCigs
        settings.targetCigs = snapshot.settings.targetCigs
        settings.packPrice = snapshot.settings.packPrice
        settings.sticksPerPack = snapshot.settings.sticksPerPack
        settings.waterGoalML = snapshot.settings.waterGoalML
        settings.waterStartHour = snapshot.settings.waterStartHour
        settings.waterEndHour = snapshot.settings.waterEndHour
        settings.waterIntervalMin = snapshot.settings.waterIntervalMin
        try? context.save()

        if settings.waterRemindersEnabled {
            Task { await NotificationScheduler.rescheduleWaterReminders(settings: settings) }
        }
    }
}

// MARK: - Passcode Sheet

struct PasscodeSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(LockStore.self) private var lock
    @Query private var settingsList: [AppSettings]
    private var settings: AppSettings { settingsList.first ?? AppSettingsStore.current(in: context) }

    @State private var passcode = ""
    @State private var confirm = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("设置访问密码") {
                    SecureField("至少 4 位", text: $passcode)
                        .keyboardType(.numberPad)
                    SecureField("再次输入", text: $confirm)
                        .keyboardType(.numberPad)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("访问密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        guard passcode.count >= 4 else { error = "密码至少 4 位"; Haptics.error(); return }
        guard passcode == confirm else { error = "两次密码不一致"; Haptics.error(); return }
        lock.setPasscode(passcode, settings: settings)
        if settings.lockMode == .off || settings.lockMode == .biometric {
            // 用户是从"需要密码"的入口过来,把默认切成 both 或 passcode
            settings.lockModeRaw = LockStore.isBiometryAvailable ? LockMode.both.rawValue : LockMode.passcode.rawValue
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}

// MARK: - Export/Import Sheets

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var password: String
    let onExport: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("备份密码") {
                    SecureField("至少 6 位", text: $password)
                } footer: {
                    Text("导入时需要相同密码。请妥善保管，密码遗失将无法恢复数据。")
                }
            }
            .navigationTitle("加密导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导出") { onExport() }.fontWeight(.semibold).disabled(password.count < 6)
                }
            }
        }
    }
}

struct ImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var password: String
    @Binding var message: String?
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("备份密码") {
                    SecureField("密码", text: $password)
                }
                if let message {
                    Section { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle("导入备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("导入") { onImport() }.fontWeight(.semibold).disabled(password.isEmpty)
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
