const STORAGE_KEY = "tx-life-tracker-v1";
const LOCK_KEY = "tx-life-tracker-lock-v1";
const isNative = typeof window.Capacitor !== "undefined";
const BiometricAuth = isNative ? window.Capacitor?.Plugins?.BiometricAuth : null;
const LocalNotifications = isNative ? window.Capacitor?.Plugins?.LocalNotifications : null;

const defaultState = {
  version: 2,
  settings: {
    smoking: { baselineCigs: 20, targetCigs: 12, packPrice: 25, sticksPerPack: 20, phase: "减量期", quitTargetDate: "" },
    water: { goal: 2000, start: "09:00", end: "22:00", interval: 90 },
    ui: { theme: "ice", dark: false },
  },
  smokingLogs: [],
  cravingLogs: [],
  waterLogs: [],
  healthLogs: [],
  workLogs: [],
  notes: [],
  achievements: [],
};

let state = loadState();
let activeScreen = "dashboard";
let activeRecordPane = "health";
let toastTimer = 0;
let timerInterval = 0;
let pendingSmokeId = null;

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

applyTheme(state.settings.ui.theme);
applyDarkMode(state.settings.ui.dark);

document.addEventListener("DOMContentLoaded", () => {
  bindNavigation();
  bindDashboardActions();
  bindSmoking();
  bindWater();
  bindRecords();
  bindSettings();
  bindModals();
  checkLock();
  renderAll();
  startTimer();
  scheduleReminders();
});

// === Utilities ===
function todayKey(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,"0")}-${String(date.getDate()).padStart(2,"0")}`;
}
function timeLabel(iso) { return new Date(iso).toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit" }); }
function dateTimeLabel(iso) { return new Date(iso).toLocaleString("zh-CN", { month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" }); }
function uid(prefix) { return `${prefix}_${Date.now()}_${Math.random().toString(16).slice(2)}`; }
function money(v) { return `¥${Number(v||0).toFixed(2)}`; }
function numberValue(sel) { return Number($(sel).value || 0); }
function escapeHtml(v) { return String(v??"").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;"); }
function daysBetween(a, b) { return Math.floor((new Date(b) - new Date(a)) / 86400000); }

function getDayKey(offset) {
  const d = new Date(); d.setDate(d.getDate() + offset);
  return todayKey(d);
}

// === State ===
function loadState() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return structuredClone(defaultState);
  try { return mergeState(JSON.parse(raw)); } catch { return structuredClone(defaultState); }
}
function mergeState(saved) {
  return {
    ...structuredClone(defaultState), ...saved,
    settings: {
      ...structuredClone(defaultState.settings), ...(saved.settings || {}),
      smoking: { ...defaultState.settings.smoking, ...((saved.settings?.smoking) || {}) },
      water: { ...defaultState.settings.water, ...((saved.settings?.water) || {}) },
      ui: { ...defaultState.settings.ui, ...((saved.settings?.ui) || {}) },
    },
    smokingLogs: saved.smokingLogs || [],
    cravingLogs: saved.cravingLogs || [],
    waterLogs: saved.waterLogs || [],
    healthLogs: saved.healthLogs || [],
    workLogs: saved.workLogs || [],
    notes: saved.notes || [],
    achievements: saved.achievements || [],
  };
}
function saveState() { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); }

// === Render ===
function renderAll() {
  $("#todayLabel").textContent = new Date().toLocaleDateString("zh-CN", { weekday: "long", month: "long", day: "numeric" });
  renderHeader();
  renderDashboard();
  renderSmoking();
  renderWater();
  renderRecords();
  renderSettings();
  checkAchievements();
}
function renderHeader() {
  const titles = { dashboard: "首页", smoking: "戒烟", water: "喝水", records: "记录", settings: "设置" };
  $("#screenTitle").textContent = titles[activeScreen];
}

// === Navigation ===
function bindNavigation() {
  $$(".tab-bar button").forEach(btn => {
    btn.addEventListener("click", () => {
      activeScreen = btn.dataset.target;
      $$(".tab-bar button").forEach(b => b.classList.toggle("is-active", b === btn));
      $$(".screen").forEach(s => {
        const isTarget = s.dataset.screen === activeScreen;
        s.classList.toggle("is-active", isTarget);
        if (isTarget) s.style.animation = "none", s.offsetHeight, s.style.animation = "";
      });
      renderAll();
    });
  });
}
function switchScreen(name) { $(`.tab-bar button[data-target="${name}"]`)?.click(); }

// === Dashboard ===
function bindDashboardActions() {
  $$(".quick-card").forEach(btn => {
    btn.addEventListener("click", () => {
      if (btn.dataset.action === "smoke") showTriggerModal();
      if (btn.dataset.action === "craving") addCravingLog();
      if (btn.dataset.action === "water250") addWater(250);
      if (btn.dataset.action === "note") { switchScreen("records"); setRecordPane("notes"); }
    });
  });
}

function getTodayLogs(collection) { const k = todayKey(); return collection.filter(i => i.date === k); }
function getLogsForDay(collection, day) { return collection.filter(i => i.date === day); }

function smokingStats() {
  const s = state.settings.smoking;
  const smoked = getTodayLogs(state.smokingLogs).length;
  const cravings = getTodayLogs(state.cravingLogs).length;
  const baseline = Number(s.baselineCigs) || 0;
  const target = Number(s.targetCigs) || 0;
  const packPrice = Number(s.packPrice) || 0;
  const sticksPerPack = Number(s.sticksPerPack) || 20;
  const pricePerStick = sticksPerPack > 0 ? packPrice / sticksPerPack : 0;
  const reduced = Math.max(baseline - smoked, 0);
  const saved = reduced * pricePerStick;
  return { smoked, cravings, baseline, target, pricePerStick, reduced, saved };
}

function renderDashboard() {
  const stats = smokingStats();
  const water = waterStats();
  $("#dashSavedDetail").textContent = `比正常少 ${stats.reduced} 根 · 省 ${money(stats.saved)}`;
  $("#quickSmokeText").textContent = `今日 ${stats.smoked} 根`;
  $("#quickCravingText").textContent = `烟瘾 ${stats.cravings} 次`;
  $("#quickWaterText").textContent = `${water.amount} / ${water.goal}ml`;
  $("#quickNoteText").textContent = `${state.notes.filter(n => !n.done).length} 条待办`;
  $("#todayScore").textContent = stats.smoked <= stats.target ? "今天还在目标内" : `超出目标 ${stats.smoked - stats.target} 根`;
  $("#smokeRingText").textContent = `${stats.smoked}/${stats.target}`;
  const ratio = stats.target > 0 ? Math.min(stats.smoked / stats.target, 1) : 0;
  $("#smokeRing").style.strokeDashoffset = String(301.59 * (1 - ratio));

  renderWeekChart();
  renderAchievementBar();

  const events = [
    ...getTodayLogs(state.smokingLogs).map(i => ({ type: "吸烟", title: `吸烟 · ${i.trigger||"未标记"}`, at: i.at })),
    ...getTodayLogs(state.cravingLogs).map(i => ({ type: "忍住", title: "忍住一次烟瘾", at: i.at })),
    ...getTodayLogs(state.waterLogs).map(i => ({ type: "喝水", title: `喝水 ${i.amount}ml`, at: i.at })),
  ].sort((a, b) => new Date(b.at) - new Date(a.at));
  renderTimeline($("#dashboardTimeline"), events.slice(0, 6), "今天还没有记录", "📝");
}

// === Timer ===
function startTimer() {
  clearInterval(timerInterval);
  updateTimer();
  timerInterval = setInterval(updateTimer, 1000);
}
function updateTimer() {
  const logs = state.smokingLogs.filter(l => l.date === todayKey() || daysBetween(l.date, todayKey()) <= 1);
  const sorted = logs.sort((a, b) => new Date(b.at) - new Date(a.at));
  const last = sorted[0];
  const el = $("#lastSmokeTimer");
  if (!last) { el.textContent = "今天还没抽"; return; }
  const diff = Math.floor((Date.now() - new Date(last.at).getTime()) / 1000);
  const h = Math.floor(diff / 3600);
  const m = Math.floor((diff % 3600) / 60);
  const s = diff % 60;
  el.textContent = `${h}:${String(m).padStart(2,"0")}:${String(s).padStart(2,"0")}`;
}

// === Week Chart ===
function renderWeekChart() {
  const canvas = $("#weekChart");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth;
  const h = 100;
  canvas.width = w * dpr; canvas.height = h * dpr;
  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, w, h);

  const days = [];
  for (let i = -6; i <= 0; i++) days.push(getDayKey(i));
  const counts = days.map(d => getLogsForDay(state.smokingLogs, d).length);
  const max = Math.max(...counts, 1);
  const barW = (w - 48) / 7;
  const gap = 6;

  const isDark = document.documentElement.classList.contains("dark");
  const accentColor = getComputedStyle(document.documentElement).getPropertyValue("--accent").trim();

  days.forEach((day, i) => {
    const x = 24 + i * barW + gap / 2;
    const barH = (counts[i] / max) * (h - 36);
    const y = h - 20 - barH;

    ctx.fillStyle = isDark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.04)";
    ctx.beginPath();
    ctx.roundRect(x, 16, barW - gap, h - 36, 6);
    ctx.fill();

    if (counts[i] > 0) {
      ctx.fillStyle = i === 6 ? accentColor : (isDark ? "rgba(255,255,255,0.2)" : "rgba(0,122,255,0.3)");
      ctx.beginPath();
      ctx.roundRect(x, y, barW - gap, barH, 6);
      ctx.fill();
    }

    ctx.fillStyle = isDark ? "rgba(255,255,255,0.4)" : "rgba(0,0,0,0.35)";
    ctx.font = "500 10px -apple-system, system-ui";
    ctx.textAlign = "center";
    const label = new Date(day).toLocaleDateString("zh-CN", { weekday: "narrow" });
    ctx.fillText(label, x + (barW - gap) / 2, h - 4);

    if (counts[i] > 0) {
      ctx.fillStyle = isDark ? "rgba(255,255,255,0.6)" : "rgba(0,0,0,0.5)";
      ctx.font = "600 10px -apple-system, system-ui";
      ctx.fillText(counts[i], x + (barW - gap) / 2, y - 4);
    }
  });
}

// === Trigger Modal ===
function bindModals() {
  $$(".trigger-grid button").forEach(btn => {
    btn.addEventListener("click", () => {
      completeSmokeLog(btn.dataset.trigger);
      hideModal("triggerModal");
    });
  });
  $("#triggerSkip").addEventListener("click", () => { completeSmokeLog(""); hideModal("triggerModal"); });
  $("#triggerModal").addEventListener("click", e => { if (e.target === e.currentTarget) { completeSmokeLog(""); hideModal("triggerModal"); } });
  $("#closeShare").addEventListener("click", () => hideModal("shareModal"));
  $("#shareModal").addEventListener("click", e => { if (e.target === e.currentTarget) hideModal("shareModal"); });
  $("#downloadShare").addEventListener("click", downloadShareImage);
  $("#shareReportButton")?.addEventListener("click", generateShareCard);
}

function showTriggerModal() {
  const now = new Date();
  pendingSmokeId = uid("smoke");
  state.smokingLogs.push({ id: pendingSmokeId, date: todayKey(now), at: now.toISOString(), trigger: "", note: "" });
  saveState();
  $("#triggerModal").classList.remove("hidden");
}

function completeSmokeLog(trigger) {
  if (pendingSmokeId) {
    const log = state.smokingLogs.find(l => l.id === pendingSmokeId);
    if (log) log.trigger = trigger;
    pendingSmokeId = null;
    saveState();
    renderAll();
    showToast("已记录一根");
  }
}

function showModal(id) { $(`#${id}`).classList.remove("hidden"); }
function hideModal(id) { $(`#${id}`).classList.add("hidden"); }

// === Smoking ===
function bindSmoking() {
  $("#addSmokeButton").addEventListener("click", showTriggerModal);
  $("#addCravingButton").addEventListener("click", addCravingLog);
  $("#delayButton").addEventListener("click", () => {
    const until = new Date(Date.now() + 10 * 60 * 1000);
    showToast(`先等到 ${timeLabel(until.toISOString())} 再决定`);
  });
  $("#undoSmokeButton").addEventListener("click", () => {
    const today = getTodayLogs(state.smokingLogs);
    if (!today.length) { showToast("今天还没有吸烟记录"); return; }
    const latest = today.sort((a, b) => new Date(b.at) - new Date(a.at))[0];
    state.smokingLogs = state.smokingLogs.filter(i => i.id !== latest.id);
    saveState(); renderAll(); showToast("已撤销最近一根");
  });
  $("#saveSmokingSettings").addEventListener("click", () => {
    state.settings.smoking = {
      baselineCigs: numberValue("#baselineCigs"), targetCigs: numberValue("#targetCigs"),
      packPrice: numberValue("#packPrice"), sticksPerPack: numberValue("#sticksPerPack") || 20,
      phase: $("#smokePhase").value, quitTargetDate: $("#quitTargetDate").value,
    };
    saveState(); renderAll(); showToast("戒烟设置已保存");
  });
}

function addSmokeLog(trigger = "") {
  const now = new Date();
  state.smokingLogs.push({ id: uid("smoke"), date: todayKey(now), at: now.toISOString(), trigger, note: "" });
  saveState(); renderAll(); showToast("已记录一根");
}

function addCravingLog() {
  const now = new Date();
  state.cravingLogs.push({ id: uid("craving"), date: todayKey(now), at: now.toISOString(), trigger: "", intensity: 3, resisted: true, note: "" });
  saveState(); renderAll(); showToast("忍住了，继续保持");
}

function renderSmoking() {
  const s = state.settings.smoking;
  const stats = smokingStats();
  $("#smokeCount").textContent = stats.smoked;
  $("#smokeTargetText").textContent = `目标 ${stats.target} 根`;
  $("#reducedCount").textContent = stats.reduced;
  $("#savedMoney").textContent = money(stats.saved);
  $("#pricePerStick").textContent = `${money(stats.pricePerStick)}/根`;
  $("#baselineCigs").value = s.baselineCigs;
  $("#targetCigs").value = s.targetCigs;
  $("#packPrice").value = s.packPrice;
  $("#sticksPerPack").value = s.sticksPerPack;
  $("#smokePhase").value = s.phase;
  $("#quitTargetDate").value = s.quitTargetDate;

  renderTriggerStats();

  const events = [
    ...getTodayLogs(state.smokingLogs).map(i => ({ title: `吸烟 · ${i.trigger||"未标记"}`, at: i.at, detail: "" })),
    ...getTodayLogs(state.cravingLogs).map(i => ({ title: "忍住烟瘾", at: i.at, detail: "这次没有抽" })),
  ].sort((a, b) => new Date(b.at) - new Date(a.at));
  renderTimeline($("#smokingTimeline"), events, "今天还没有戒烟记录", "🚭");
}

function renderTriggerStats() {
  const container = $("#triggerStats");
  const triggers = ["饭后", "压力", "无聊", "社交", "习惯", "情绪", "提神", "其他"];
  const last7 = [];
  for (let i = -6; i <= 0; i++) last7.push(getDayKey(i));
  const logs = state.smokingLogs.filter(l => last7.includes(l.date));
  const counts = {};
  triggers.forEach(t => counts[t] = 0);
  logs.forEach(l => { if (l.trigger && counts[l.trigger] !== undefined) counts[l.trigger]++; });
  const max = Math.max(...Object.values(counts), 1);

  container.innerHTML = triggers
    .filter(t => counts[t] > 0)
    .sort((a, b) => counts[b] - counts[a])
    .slice(0, 5)
    .map(t => `<div class="trigger-row">
      <span class="trigger-label">${t}</span>
      <div class="trigger-bar-bg"><div class="trigger-bar-fill" style="width:${(counts[t]/max)*100}%"></div></div>
      <span class="trigger-count">${counts[t]}</span>
    </div>`).join("") || '<div class="empty-state" data-icon="📊">记录诱因后这里会显示统计</div>';
}

// === Water ===
function bindWater() {
  $$(".amount-grid button").forEach(btn => {
    btn.addEventListener("click", () => addWater(Number(btn.dataset.water)));
  });
  $("#undoWaterButton").addEventListener("click", () => {
    const today = getTodayLogs(state.waterLogs);
    if (!today.length) { showToast("今天还没有喝水记录"); return; }
    const latest = today.sort((a, b) => new Date(b.at) - new Date(a.at))[0];
    state.waterLogs = state.waterLogs.filter(i => i.id !== latest.id);
    saveState(); renderAll(); showToast("已撤销最近喝水记录");
  });
  $("#saveWaterSettings").addEventListener("click", () => {
    state.settings.water = {
      goal: numberValue("#waterGoal"), start: $("#waterStart").value,
      end: $("#waterEnd").value, interval: numberValue("#waterInterval") || 90,
    };
    saveState(); renderAll(); showToast("喝水设置已保存");
  });
  $("#enableWaterReminder").addEventListener("click", requestNotificationPermission);
}

function addWater(amount) {
  const now = new Date();
  state.waterLogs.push({ id: uid("water"), date: todayKey(now), at: now.toISOString(), amount });
  saveState(); renderAll(); showToast(`已记录喝水 ${amount}ml`);
}

function waterStats() {
  const amount = getTodayLogs(state.waterLogs).reduce((s, i) => s + Number(i.amount || 0), 0);
  const goal = Number(state.settings.water.goal) || 0;
  return { amount, goal, ratio: goal > 0 ? Math.min(amount / goal, 1) : 0 };
}

function renderWater() {
  const stats = waterStats();
  $("#waterAmount").textContent = `${stats.amount}ml`;
  $("#waterGoalText").textContent = `目标 ${stats.goal}ml`;
  $("#waterBar").style.width = `${stats.ratio * 100}%`;
  $("#waterGoal").value = state.settings.water.goal;
  $("#waterStart").value = state.settings.water.start;
  $("#waterEnd").value = state.settings.water.end;
  $("#waterInterval").value = state.settings.water.interval;

  renderWaterWeekChart();

  const events = getTodayLogs(state.waterLogs)
    .map(i => ({ title: `喝水 ${i.amount}ml`, at: i.at, detail: "" }))
    .sort((a, b) => new Date(b.at) - new Date(a.at));
  renderTimeline($("#waterTimeline"), events, "今天还没有喝水记录", "💧");
}

function renderWaterWeekChart() {
  const canvas = $("#waterWeekChart");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth; const h = 80;
  canvas.width = w * dpr; canvas.height = h * dpr;
  ctx.scale(dpr, dpr); ctx.clearRect(0, 0, w, h);

  const days = []; for (let i = -6; i <= 0; i++) days.push(getDayKey(i));
  const amounts = days.map(d => getLogsForDay(state.waterLogs, d).reduce((s, l) => s + (l.amount || 0), 0));
  const goal = state.settings.water.goal || 2000;
  const max = Math.max(...amounts, goal);
  const barW = (w - 48) / 7; const gap = 6;
  const isDark = document.documentElement.classList.contains("dark");

  days.forEach((day, i) => {
    const x = 24 + i * barW + gap / 2;
    const barH = (amounts[i] / max) * (h - 28);
    const y = h - 16 - barH;
    ctx.fillStyle = isDark ? "rgba(255,255,255,0.06)" : "rgba(0,0,0,0.04)";
    ctx.beginPath(); ctx.roundRect(x, 12, barW - gap, h - 28, 5); ctx.fill();
    if (amounts[i] > 0) {
      ctx.fillStyle = amounts[i] >= goal ? "#30d158" : "#0a84ff";
      ctx.globalAlpha = i === 6 ? 1 : 0.5;
      ctx.beginPath(); ctx.roundRect(x, y, barW - gap, barH, 5); ctx.fill();
      ctx.globalAlpha = 1;
    }
    ctx.fillStyle = isDark ? "rgba(255,255,255,0.4)" : "rgba(0,0,0,0.35)";
    ctx.font = "500 10px -apple-system, system-ui"; ctx.textAlign = "center";
    ctx.fillText(new Date(day).toLocaleDateString("zh-CN", { weekday: "narrow" }), x + (barW - gap) / 2, h - 2);
  });
}

// === Records ===
function bindRecords() {
  $$(".segmented-control button").forEach(btn => {
    btn.addEventListener("click", () => setRecordPane(btn.dataset.recordTab));
  });
  $("#healthForm").addEventListener("submit", e => {
    e.preventDefault();
    const d = new FormData(e.currentTarget);
    state.healthLogs.unshift({ id: uid("health"), date: todayKey(), createdAt: new Date().toISOString(), weight: d.get("weight"), sleep: d.get("sleep"), mood: d.get("mood"), energy: d.get("energy"), bodyNote: d.get("bodyNote") });
    e.currentTarget.reset(); saveState(); renderAll(); showToast("健康记录已保存");
  });
  $("#workForm").addEventListener("submit", e => {
    e.preventDefault();
    const d = new FormData(e.currentTarget);
    state.workLogs.unshift({ id: uid("work"), date: todayKey(), createdAt: new Date().toISOString(), start: d.get("start"), end: d.get("end"), status: d.get("status"), hours: d.get("hours"), note: d.get("note") });
    e.currentTarget.reset(); saveState(); renderAll(); showToast("上班记录已保存");
  });
  $("#noteForm").addEventListener("submit", e => {
    e.preventDefault();
    const d = new FormData(e.currentTarget);
    const title = String(d.get("title")||"").trim();
    const content = String(d.get("content")||"").trim();
    if (!title && !content) { showToast("先写点内容"); return; }
    state.notes.unshift({ id: uid("note"), createdAt: new Date().toISOString(), title: title || "未命名备忘", content, tag: String(d.get("tag")||"").trim(), remindAt: d.get("remindAt"), pinned: d.get("pinned") === "on", done: false });
    e.currentTarget.reset(); saveState(); renderAll(); showToast("备忘已保存");
  });
  $("#noteSearch").addEventListener("input", renderRecords);
}

function setRecordPane(pane) {
  activeRecordPane = pane;
  $$(".segmented-control button").forEach(b => b.classList.toggle("is-selected", b.dataset.recordTab === pane));
  $$(".record-pane").forEach(p => p.classList.toggle("is-active", p.dataset.recordPane === pane));
}

function renderRecords() {
  setRecordPane(activeRecordPane);
  renderHealthList(); renderWorkList(); renderNoteList(); renderWeeklyReport(); renderCorrelation();
}

function renderHealthList() {
  const items = state.healthLogs.slice(0, 8).map(i => {
    const bits = [`心情 ${i.mood}`, `精力 ${i.energy}`];
    if (i.weight) bits.push(`${i.weight}kg`);
    if (i.sleep) bits.push(`${i.sleep}h`);
    return { title: dateTimeLabel(i.createdAt), at: i.createdAt, detail: bits.join(" · ") + (i.bodyNote ? ` · ${i.bodyNote}` : "") };
  });
  renderList($("#healthList"), items, "还没有健康记录");
}

function renderWorkList() {
  const items = state.workLogs.slice(0, 8).map(i => {
    const range = i.start || i.end ? `${i.start||"--:--"} - ${i.end||"--:--"}` : "未填写";
    return { title: `${i.status} · ${range}`, at: i.createdAt, detail: `${i.hours ? `${i.hours}h` : ""}${i.note ? ` · ${i.note}` : ""}` };
  });
  renderList($("#workList"), items, "还没有上班记录");
}

function renderNoteList() {
  const query = $("#noteSearch").value.trim().toLowerCase();
  const notes = state.notes
    .filter(n => !query || [n.title, n.content, n.tag].join(" ").toLowerCase().includes(query))
    .sort((a, b) => Number(b.pinned) - Number(a.pinned) || new Date(b.createdAt) - new Date(a.createdAt));
  const container = $("#noteList");
  container.innerHTML = "";
  if (!notes.length) { container.append(emptyState("没有匹配的备忘", "📋")); return; }
  notes.slice(0, 16).forEach(note => {
    const item = document.createElement("article");
    item.className = "list-item";
    item.innerHTML = `<header><strong>${escapeHtml(note.pinned ? `📌 ${note.title}` : note.title)}</strong><button class="text-button" type="button" data-note-toggle="${note.id}">${note.done ? "恢复" : "完成"}</button></header><p>${escapeHtml(note.content || "无内容")}</p><span>${dateTimeLabel(note.createdAt)}${note.tag ? ` · ${escapeHtml(note.tag)}` : ""}</span>`;
    container.append(item);
  });
  $$("[data-note-toggle]").forEach(btn => {
    btn.addEventListener("click", () => {
      const note = state.notes.find(n => n.id === btn.dataset.noteToggle);
      if (note) { note.done = !note.done; saveState(); renderAll(); }
    });
  });
}

// === Weekly Report ===
function renderWeeklyReport() {
  const container = $("#weeklyReport");
  if (!container) return;
  const days = []; for (let i = -6; i <= 0; i++) days.push(getDayKey(i));
  const prevDays = []; for (let i = -13; i <= -7; i++) prevDays.push(getDayKey(i));

  const thisWeekSmoke = days.reduce((s, d) => s + getLogsForDay(state.smokingLogs, d).length, 0);
  const lastWeekSmoke = prevDays.reduce((s, d) => s + getLogsForDay(state.smokingLogs, d).length, 0);
  const thisWeekWater = days.reduce((s, d) => s + getLogsForDay(state.waterLogs, d).reduce((a, l) => a + (l.amount||0), 0), 0);
  const thisWeekCraving = days.reduce((s, d) => s + getLogsForDay(state.cravingLogs, d).length, 0);
  const avgSmoke = (thisWeekSmoke / 7).toFixed(1);
  const diff = thisWeekSmoke - lastWeekSmoke;
  const s = state.settings.smoking;
  const saved = Math.max((s.baselineCigs * 7 - thisWeekSmoke), 0) * ((s.packPrice || 25) / (s.sticksPerPack || 20));

  const startLabel = new Date(days[0]).toLocaleDateString("zh-CN", { month: "numeric", day: "numeric" });
  const endLabel = new Date(days[6]).toLocaleDateString("zh-CN", { month: "numeric", day: "numeric" });
  $("#reportRange").textContent = `${startLabel} - ${endLabel}`;

  container.innerHTML = `
    <div class="report-stat"><span class="report-label">本周吸烟</span><span class="report-value">${thisWeekSmoke} 根</span></div>
    <div class="report-stat"><span class="report-label">日均</span><span class="report-value">${avgSmoke} 根/天</span></div>
    <div class="report-stat"><span class="report-label">对比上周</span><span class="report-value ${diff <= 0 ? "positive" : "negative"}">${diff <= 0 ? "↓" : "↑"} ${Math.abs(diff)} 根</span></div>
    <div class="report-stat"><span class="report-label">忍住次数</span><span class="report-value positive">${thisWeekCraving} 次</span></div>
    <div class="report-stat"><span class="report-label">本周喝水</span><span class="report-value">${(thisWeekWater/1000).toFixed(1)}L</span></div>
    <div class="report-stat"><span class="report-label">本周省下</span><span class="report-value positive">${money(saved)}</span></div>
  `;
}

// === Health Correlation ===
function renderCorrelation() {
  const container = $("#correlationView");
  if (!container) return;
  const moods = ["开心", "平稳", "烦躁", "低落", "焦虑"];
  const moodSmoke = {};
  moods.forEach(m => moodSmoke[m] = { total: 0, days: 0 });

  state.healthLogs.forEach(h => {
    if (h.mood && moodSmoke[h.mood]) {
      const daySmoke = getLogsForDay(state.smokingLogs, h.date).length;
      moodSmoke[h.mood].total += daySmoke;
      moodSmoke[h.mood].days++;
    }
  });

  const avgs = moods.map(m => ({ mood: m, avg: moodSmoke[m].days > 0 ? moodSmoke[m].total / moodSmoke[m].days : 0 }));
  const max = Math.max(...avgs.map(a => a.avg), 1);

  if (avgs.every(a => a.avg === 0)) {
    container.innerHTML = '<div class="empty-state" data-icon="🔗">记录健康数据后显示关联分析</div>';
    return;
  }

  container.innerHTML = avgs.filter(a => a.avg > 0).map(a => `
    <div class="corr-row">
      <span class="corr-mood">${a.mood}</span>
      <div class="corr-bar-bg"><div class="corr-bar-fill" style="width:${(a.avg/max)*100}%"></div></div>
      <span class="corr-val">${a.avg.toFixed(1)}</span>
    </div>
  `).join("");
}

// === Achievements ===
const ACHIEVEMENTS = [
  { id: "first_resist", icon: "💪", name: "第一次忍住", desc: "忍住一次烟瘾", check: s => s.cravingLogs.length >= 1 },
  { id: "resist_5", icon: "🛡️", name: "意志坚定", desc: "累计忍住5次", check: s => s.cravingLogs.length >= 5 },
  { id: "resist_20", icon: "🏆", name: "钢铁意志", desc: "累计忍住20次", check: s => s.cravingLogs.length >= 20 },
  { id: "under_target", icon: "🎯", name: "达标一天", desc: "某天吸烟量在目标内", check: s => { const t = getTodayLogs(s.smokingLogs).length; return t > 0 && t <= (s.settings.smoking.targetCigs || 99); } },
  { id: "streak_3", icon: "🔥", name: "连续3天达标", desc: "连续3天在目标内", check: s => getStreak(s) >= 3 },
  { id: "streak_7", icon: "⭐", name: "一周达标", desc: "连续7天在目标内", check: s => getStreak(s) >= 7 },
  { id: "save_50", icon: "💰", name: "省下50元", desc: "累计省下50元", check: s => getTotalSaved(s) >= 50 },
  { id: "save_100", icon: "💎", name: "省下100元", desc: "累计省下100元", check: s => getTotalSaved(s) >= 100 },
  { id: "water_7", icon: "💧", name: "水润一周", desc: "连续7天喝水达标", check: s => getWaterStreak(s) >= 7 },
  { id: "half_smoke", icon: "📉", name: "减半成功", desc: "某天吸烟量≤正常的一半", check: s => { const t = getTodayLogs(s.smokingLogs).length; return t > 0 && t <= Math.floor((s.settings.smoking.baselineCigs||20)/2); } },
];

function getStreak(s) {
  const target = s.settings.smoking.targetCigs || 99;
  let streak = 0;
  for (let i = 0; i >= -30; i--) {
    const d = getDayKey(i);
    const count = getLogsForDay(s.smokingLogs, d).length;
    if (i === 0 && count === 0) continue;
    if (count <= target && count > 0) streak++;
    else break;
  }
  return streak;
}

function getTotalSaved(s) {
  const baseline = s.settings.smoking.baselineCigs || 20;
  const price = (s.settings.smoking.packPrice || 25) / (s.settings.smoking.sticksPerPack || 20);
  let saved = 0;
  for (let i = -30; i <= 0; i++) {
    const d = getDayKey(i);
    const count = getLogsForDay(s.smokingLogs, d).length;
    saved += Math.max(baseline - count, 0) * price;
  }
  return saved;
}

function getWaterStreak(s) {
  const goal = s.settings.water.goal || 2000;
  let streak = 0;
  for (let i = 0; i >= -30; i--) {
    const d = getDayKey(i);
    const amount = getLogsForDay(s.waterLogs, d).reduce((a, l) => a + (l.amount||0), 0);
    if (i === 0 && amount === 0) continue;
    if (amount >= goal) streak++;
    else break;
  }
  return streak;
}

function checkAchievements() {
  let newUnlock = false;
  ACHIEVEMENTS.forEach(ach => {
    if (state.achievements.includes(ach.id)) return;
    if (ach.check(state)) { state.achievements.push(ach.id); newUnlock = true; }
  });
  if (newUnlock) { saveState(); renderAchievementBar(); }
  renderAchievementList();
}

function renderAchievementBar() {
  const bar = $("#achievementBar");
  const recent = ACHIEVEMENTS.filter(a => state.achievements.includes(a.id)).slice(-3);
  bar.innerHTML = recent.map(a => `<div class="achievement-badge"><span class="badge-icon">${a.icon}</span>${a.name}</div>`).join("");
}

function renderAchievementList() {
  const container = $("#achievementList");
  if (!container) return;
  $("#achievementCount").textContent = `${state.achievements.length} / ${ACHIEVEMENTS.length}`;
  container.innerHTML = ACHIEVEMENTS.map(a => {
    const unlocked = state.achievements.includes(a.id);
    return `<div class="achievement-item ${unlocked ? "" : "locked"}"><span class="ach-icon">${a.icon}</span><div class="ach-info">${a.name}<small>${a.desc}</small></div></div>`;
  }).join("");
}

// === Settings ===
function bindSettings() {
  $$(".theme-swatch").forEach(btn => {
    btn.addEventListener("click", () => { applyTheme(btn.dataset.theme); saveState(); renderSettings(); showToast(`已切换到${themeLabel(btn.dataset.theme)}`); });
  });
  $("#darkModeToggle").addEventListener("change", e => {
    applyDarkMode(e.target.checked); state.settings.ui.dark = e.target.checked; saveState(); renderAll();
  });
  $("#lockNowButton").addEventListener("click", lockApp);
  $("#unlockForm").addEventListener("submit", unlockApp);
  $("#retryBiometric").addEventListener("click", async () => {
    if (BiometricAuth) {
      try { await BiometricAuth.authenticate({ reason: "验证身份以查看记录" }); hideLock(); showToast("已解锁"); } catch {}
    } else { showToast("当前设备不支持 Face ID"); }
  });
  $("#resetLockButton").addEventListener("click", () => {
    if (!confirm("确定重设本机锁吗？")) return;
    localStorage.removeItem(LOCK_KEY); hideLock(); renderSettings(); showToast("已重设本机锁");
  });
  $("#lockForm").addEventListener("submit", e => {
    e.preventDefault();
    const p = new FormData(e.currentTarget).get("passcode");
    if (!p || String(p).length < 4) { showToast("访问密码至少 4 位"); return; }
    localStorage.setItem(LOCK_KEY, JSON.stringify({ passcode: String(p), enabled: true }));
    e.currentTarget.reset(); renderSettings(); showToast("隐私锁已启用");
  });
  $("#exportButton").addEventListener("click", exportEncryptedBackup);
  $("#exportPlainButton").addEventListener("click", exportPlainJson);
  $("#importFile").addEventListener("change", importBackup);
  $("#seedButton").addEventListener("click", seedDemoData);
  $("#clearDataButton").addEventListener("click", () => {
    if (!confirm("确定清空本机全部数据吗？")) return;
    state = structuredClone(defaultState); saveState(); renderAll(); showToast("已清空本机数据");
  });
}

function renderSettings() {
  const lock = getLockConfig();
  $("#lockStatus").textContent = lock.enabled ? "已启用" : "未设置";
  $("#themeStatus").textContent = themeLabel(state.settings.ui.theme);
  $("#darkModeToggle").checked = state.settings.ui.dark;
  $$(".theme-swatch").forEach(b => b.classList.toggle("is-selected", b.dataset.theme === state.settings.ui.theme));
  $("#dataSummary").innerHTML = `
    <div><strong>${state.smokingLogs.length}</strong><span>吸烟记录</span></div>
    <div><strong>${state.cravingLogs.length}</strong><span>烟瘾记录</span></div>
    <div><strong>${state.waterLogs.length}</strong><span>喝水记录</span></div>
    <div><strong>${state.healthLogs.length + state.workLogs.length + state.notes.length}</strong><span>其他记录</span></div>
  `;
}

function applyTheme(theme) {
  const safe = ["ice","graphite","coral","sage"].includes(theme) ? theme : "ice";
  document.documentElement.dataset.theme = safe;
  state.settings.ui.theme = safe;
}
function applyDarkMode(dark) {
  document.documentElement.classList.toggle("dark", !!dark);
}
function themeLabel(t) { return { ice: "冰蓝", graphite: "石墨", coral: "珊瑚", sage: "苔青" }[t] || "冰蓝"; }

// === Lock (Face ID / Passcode) ===
function getLockConfig() { try { return JSON.parse(localStorage.getItem(LOCK_KEY)) || { enabled: false }; } catch { return { enabled: false }; } }
function checkLock() { if (getLockConfig().enabled) lockApp(); }

async function lockApp() {
  if (!getLockConfig().enabled) { showToast("先在设置里启用隐私锁"); return; }
  $("#lockScreen").classList.remove("hidden");
  if (BiometricAuth) {
    try {
      await BiometricAuth.authenticate({ reason: "验证身份以查看记录", cancelTitle: "使用密码" });
      hideLock(); showToast("已解锁"); return;
    } catch {}
  }
  $("#unlockPasscode").focus();
}

function hideLock() { $("#lockScreen").classList.add("hidden"); }

function unlockApp(e) {
  e.preventDefault();
  const lock = getLockConfig();
  if ($("#unlockPasscode").value === lock.passcode) { $("#unlockPasscode").value = ""; hideLock(); showToast("已解锁"); }
  else showToast("访问密码不正确");
}

// === Notifications / Reminders ===
async function requestNotificationPermission() {
  if (LocalNotifications) {
    const perm = await LocalNotifications.requestPermissions();
    if (perm.display === "granted") { showToast("提醒已开启"); scheduleNativeReminders(); }
    else showToast("需要在系统设置中允许通知");
    return;
  }
  if (!("Notification" in window)) { showToast("当前浏览器不支持通知"); return; }
  Notification.requestPermission().then(p => {
    if (p === "granted") { showToast("提醒已开启"); scheduleReminders(); }
    else showToast("需要允许通知权限");
  });
}

async function scheduleNativeReminders() {
  if (!LocalNotifications) return;
  await LocalNotifications.cancel({ notifications: [{ id: 1001 }, { id: 1002 }, { id: 1003 }] }).catch(() => {});
  const ws = state.settings.water;
  const [startH, startM] = ws.start.split(":").map(Number);
  const [endH] = ws.end.split(":").map(Number);
  const notifications = [];
  let id = 2000;
  for (let h = startH; h <= endH; h++) {
    for (let m = (h === startH ? startM : 0); m < 60; m += ws.interval) {
      notifications.push({
        id: id++,
        title: "💧 该喝水了",
        body: `别忘了补水，今日目标 ${ws.goal}ml`,
        schedule: { on: { hour: h, minute: m }, repeats: true },
      });
    }
  }
  // Smoking encouragement at common craving times
  [10, 14, 16, 20].forEach((h, i) => {
    notifications.push({
      id: 3000 + i,
      title: "🚭 忍一忍",
      body: "深呼吸，这波烟瘾马上就过去了",
      schedule: { on: { hour: h, minute: 0 }, repeats: true },
    });
  });
  await LocalNotifications.schedule({ notifications });
}

let reminderTimer = 0;
function scheduleReminders() {
  clearInterval(reminderTimer);
  if (isNative) { scheduleNativeReminders(); return; }
  if (!("Notification" in window) || Notification.permission !== "granted") return;
  reminderTimer = setInterval(() => {
    const now = new Date();
    const hhmm = `${String(now.getHours()).padStart(2,"0")}:${String(now.getMinutes()).padStart(2,"0")}`;
    const ws = state.settings.water;
    if (hhmm >= ws.start && hhmm <= ws.end) {
      const water = waterStats();
      if (water.amount < water.goal) {
        new Notification("💧 该喝水了", { body: `今天还差 ${water.goal - water.amount}ml` });
      }
    }
    const smokeLogs = getTodayLogs(state.smokingLogs);
    if (smokeLogs.length > 0) {
      const lastTime = new Date(smokeLogs.sort((a,b) => new Date(b.at)-new Date(a.at))[0].at);
      const minSince = (Date.now() - lastTime.getTime()) / 60000;
      if (minSince > 20 && minSince < 22) {
        new Notification("🚭 忍一忍", { body: "已经20分钟了，再坚持一下！" });
      }
    }
  }, state.settings.water.interval * 60 * 1000);
}

// === Share Card ===
function generateShareCard() {
  const canvas = $("#shareCanvas");
  const ctx = canvas.getContext("2d");
  const w = 600, h = 400;
  canvas.width = w; canvas.height = h;

  // Background
  const grad = ctx.createLinearGradient(0, 0, w, h);
  grad.addColorStop(0, "#667eea"); grad.addColorStop(1, "#764ba2");
  ctx.fillStyle = grad; ctx.fillRect(0, 0, w, h);

  // Glass card
  ctx.fillStyle = "rgba(255,255,255,0.15)";
  ctx.beginPath(); ctx.roundRect(30, 30, w-60, h-60, 24); ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,0.3)"; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.roundRect(30, 30, w-60, h-60, 24); ctx.stroke();

  ctx.fillStyle = "#fff"; ctx.font = "bold 28px -apple-system, system-ui";
  ctx.fillText("戒烟周报", 60, 80);

  const days = []; for (let i = -6; i <= 0; i++) days.push(getDayKey(i));
  const thisWeek = days.reduce((s, d) => s + getLogsForDay(state.smokingLogs, d).length, 0);
  const cravings = days.reduce((s, d) => s + getLogsForDay(state.cravingLogs, d).length, 0);
  const saved = getTotalSaved(state);

  ctx.font = "500 16px -apple-system, system-ui"; ctx.fillStyle = "rgba(255,255,255,0.7)";
  const startL = new Date(days[0]).toLocaleDateString("zh-CN", { month: "numeric", day: "numeric" });
  const endL = new Date(days[6]).toLocaleDateString("zh-CN", { month: "numeric", day: "numeric" });
  ctx.fillText(`${startL} - ${endL}`, 60, 110);

  ctx.fillStyle = "#fff"; ctx.font = "bold 48px -apple-system, system-ui";
  ctx.fillText(`${thisWeek} 根`, 60, 180);
  ctx.font = "500 16px -apple-system, system-ui"; ctx.fillStyle = "rgba(255,255,255,0.8)";
  ctx.fillText("本周吸烟", 60, 210);

  ctx.fillStyle = "#fff"; ctx.font = "bold 36px -apple-system, system-ui";
  ctx.fillText(`${cravings} 次`, 60, 280);
  ctx.font = "500 14px -apple-system, system-ui"; ctx.fillStyle = "rgba(255,255,255,0.7)";
  ctx.fillText("忍住烟瘾", 60, 305);

  ctx.fillStyle = "#fff"; ctx.font = "bold 36px -apple-system, system-ui";
  ctx.fillText(money(saved), 300, 280);
  ctx.font = "500 14px -apple-system, system-ui"; ctx.fillStyle = "rgba(255,255,255,0.7)";
  ctx.fillText("累计省下", 300, 305);

  // Streak
  const streak = getStreak(state);
  if (streak > 0) {
    ctx.fillStyle = "#ffd60a"; ctx.font = "bold 24px -apple-system, system-ui";
    ctx.fillText(`🔥 连续 ${streak} 天达标`, 60, 355);
  }

  ctx.fillStyle = "rgba(255,255,255,0.4)"; ctx.font = "400 12px -apple-system, system-ui";
  ctx.fillText("日常戒烟记录 App", w - 160, h - 50);

  showModal("shareModal");
}

function downloadShareImage() {
  const canvas = $("#shareCanvas");
  const link = document.createElement("a");
  link.download = `quit-smoking-report-${todayKey()}.png`;
  link.href = canvas.toDataURL("image/png");
  link.click();
  showToast("图片已保存");
}

// === Backup ===
async function exportEncryptedBackup() {
  const password = $("#backupPassword").value;
  if (!password || password.length < 6) { showToast("备份密码至少 6 位"); return; }
  try {
    const payload = await encryptBackup(state, password);
    downloadFile(`tx-life-backup-${todayKey()}.txbak`, JSON.stringify(payload, null, 2), "application/json");
    showToast("加密备份已生成");
  } catch { showToast("当前浏览器不支持加密导出"); }
}
function exportPlainJson() { downloadFile(`tx-life-dev-${todayKey()}.json`, JSON.stringify(state, null, 2), "application/json"); showToast("开发 JSON 已导出"); }

async function importBackup(e) {
  const file = e.target.files[0]; if (!file) return;
  const password = $("#backupPassword").value;
  try {
    const text = await file.text();
    const data = JSON.parse(text);
    let imported = data;
    if (data.kind === "tx-life-encrypted-backup") {
      if (!password) { showToast("请输入备份密码"); e.target.value = ""; return; }
      imported = await decryptBackup(data, password);
    }
    if (!imported || !imported.version) throw new Error("invalid");
    const mode = confirm("确定覆盖？取消则合并导入。") ? "replace" : "merge";
    state = mode === "replace" ? mergeState(imported) : mergeImportedState(state, imported);
    saveState(); renderAll(); showToast(mode === "replace" ? "已覆盖恢复" : "已合并导入");
  } catch { showToast("导入失败"); } finally { e.target.value = ""; }
}

function mergeImportedState(current, imported) {
  const merged = mergeState(current);
  ["smokingLogs","cravingLogs","waterLogs","healthLogs","workLogs","notes"].forEach(key => {
    const byId = new Map(merged[key].map(i => [i.id, i]));
    (imported[key]||[]).forEach(i => byId.set(i.id || uid(key), i));
    merged[key] = Array.from(byId.values());
  });
  return merged;
}

async function encryptBackup(data, password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(password, salt);
  const encoded = new TextEncoder().encode(JSON.stringify(data));
  const cipher = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encoded);
  return { kind: "tx-life-encrypted-backup", version: 1, salt: toBase64(salt), iv: toBase64(iv), data: toBase64(new Uint8Array(cipher)), createdAt: new Date().toISOString() };
}
async function decryptBackup(payload, password) {
  const key = await deriveKey(password, fromBase64(payload.salt));
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: fromBase64(payload.iv) }, key, fromBase64(payload.data));
  return JSON.parse(new TextDecoder().decode(plain));
}
async function deriveKey(password, salt) {
  const material = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey({ name: "PBKDF2", salt, iterations: 120000, hash: "SHA-256" }, material, { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
}
function toBase64(bytes) { let b = ""; bytes.forEach(x => b += String.fromCharCode(x)); return btoa(b); }
function fromBase64(v) { const b = atob(v); return Uint8Array.from(b, c => c.charCodeAt(0)); }
function downloadFile(name, content, type) {
  const blob = new Blob([content], { type }); const url = URL.createObjectURL(blob);
  const a = document.createElement("a"); a.href = url; a.download = name; document.body.append(a); a.click(); a.remove(); URL.revokeObjectURL(url);
}

// === Seed Demo ===
function seedDemoData() {
  const now = new Date();
  for (let i = -6; i <= 0; i++) {
    const d = getDayKey(i);
    const count = Math.floor(Math.random() * 8) + 5;
    const triggers = ["饭后","压力","无聊","社交","习惯","情绪","提神"];
    for (let j = 0; j < count; j++) {
      const t = new Date(now); t.setDate(t.getDate() + i); t.setHours(8 + j * 2, Math.floor(Math.random()*60));
      state.smokingLogs.push({ id: uid("smoke"), date: d, at: t.toISOString(), trigger: triggers[Math.floor(Math.random()*triggers.length)], note: "" });
    }
    const cravCount = Math.floor(Math.random() * 3) + 1;
    for (let j = 0; j < cravCount; j++) {
      const t = new Date(now); t.setDate(t.getDate() + i); t.setHours(10 + j * 4, Math.floor(Math.random()*60));
      state.cravingLogs.push({ id: uid("craving"), date: d, at: t.toISOString(), trigger: "", intensity: 3, resisted: true, note: "" });
    }
    const waterCount = Math.floor(Math.random() * 4) + 3;
    for (let j = 0; j < waterCount; j++) {
      const t = new Date(now); t.setDate(t.getDate() + i); t.setHours(9 + j * 2, Math.floor(Math.random()*60));
      state.waterLogs.push({ id: uid("water"), date: d, at: t.toISOString(), amount: [100,250,250,500][Math.floor(Math.random()*4)] });
    }
  }
  state.healthLogs.unshift(
    { id: uid("health"), date: todayKey(), createdAt: now.toISOString(), weight: "70.5", sleep: "7", mood: "平稳", energy: "普通", bodyNote: "咳嗽少了" },
    { id: uid("health"), date: getDayKey(-1), createdAt: new Date(Date.now()-86400000).toISOString(), weight: "70.8", sleep: "6.5", mood: "烦躁", energy: "疲惫", bodyNote: "" },
    { id: uid("health"), date: getDayKey(-2), createdAt: new Date(Date.now()-172800000).toISOString(), weight: "71", sleep: "8", mood: "开心", energy: "很好", bodyNote: "跑步30分钟" }
  );
  state.workLogs.unshift({ id: uid("work"), date: todayKey(), createdAt: now.toISOString(), start: "09:00", end: "18:30", status: "正常", hours: "8.5", note: "" });
  state.notes.unshift({ id: uid("note"), createdAt: now.toISOString(), title: "买薄荷糖", content: "烟瘾上来先吃一颗，再等十分钟。", tag: "戒烟", remindAt: "", pinned: true, done: false });
  saveState(); renderAll(); showToast("已填充7天示例数据");
}

// === Render Helpers ===
function renderTimeline(container, events, emptyText, icon = "📝") {
  container.innerHTML = "";
  if (!events.length) { container.append(emptyState(emptyText, icon)); return; }
  events.forEach((ev, i) => {
    const item = document.createElement("article");
    item.className = "timeline-item";
    item.style.animationDelay = `${i * 0.04}s`;
    item.innerHTML = `<header><strong>${escapeHtml(ev.title)}</strong><span>${timeLabel(ev.at)}</span></header>${ev.detail ? `<p>${escapeHtml(ev.detail)}</p>` : ""}`;
    container.append(item);
  });
}

function renderList(container, items, emptyText) {
  container.innerHTML = "";
  if (!items.length) { container.append(emptyState(emptyText, "📋")); return; }
  items.forEach((ev, i) => {
    const item = document.createElement("article");
    item.className = "list-item";
    item.style.animationDelay = `${i * 0.04}s`;
    item.innerHTML = `<header><strong>${escapeHtml(ev.title)}</strong><span>${dateTimeLabel(ev.at)}</span></header>${ev.detail ? `<p>${escapeHtml(ev.detail)}</p>` : ""}`;
    container.append(item);
  });
}

function emptyState(text, icon = "📝") {
  const node = document.createElement("div");
  node.className = "empty-state";
  node.dataset.icon = icon;
  node.textContent = text;
  return node;
}

function showToast(message) {
  const toast = $("#toast");
  toast.textContent = message;
  toast.classList.add("is-visible");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("is-visible"), 2200);
}
