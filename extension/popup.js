// popup.js — LiberationDPI Switch

let currentTabId = null;
let currentTabUrl = null;
let state = null;

const $ = (id) => document.getElementById(id);

function send(message) {
  return chrome.runtime.sendMessage(message);
}

async function getActiveTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  return tab;
}

async function refresh() {
  const tab = await getActiveTab();
  if (!tab) return;
  currentTabId = tab.id;
  currentTabUrl = tab.url;
  state = await send({ type: "GET_STATE", tabId: currentTabId, tabUrl: currentTabUrl });
  render();
}

function render() {
  if (!state) return;
  renderHeader();
  renderPageView();
  renderRulesView();
  renderFooter();
}

function renderHeader() {
  const master = $("masterSwitch");
  master.setAttribute("aria-checked", state.proxyEnabled ? "true" : "false");
  $("masterSwitchLabel").textContent = state.proxyEnabled ? "Tunnel on" : "Tunnel off";
  $("statusDot").classList.toggle("off", !state.proxyEnabled);
  $("ruleCountBadge").textContent = state.rules.length ? state.rules.length : "";
}

function renderPageView() {
  $("pageMeta").textContent = currentTabUrl || "—";

  const list = $("domainList");
  list.innerHTML = "";

  const domains = state.failedDomains || [];
  $("pageEmpty").hidden = domains.length > 0;
  list.hidden = domains.length === 0;

  for (const entry of domains) {
    list.appendChild(buildDomainRow(entry));
  }
}

function buildDomainRow(entry) {
  const li = document.createElement("li");
  li.className = "domain-row";

  const info = document.createElement("div");
  info.className = "domain-info";

  const name = document.createElement("span");
  name.className = "domain-name";
  name.textContent = entry.domain;
  name.title = entry.domain;

  const count = document.createElement("span");
  count.className = "fail-count";
  count.textContent = entry.count;

  info.append(name, count);

  const rail = buildRailSwitch(entry.mode, (mode) => setDomainMode(entry.domain, mode));

  li.append(info, rail);
  return li;
}

function buildRailSwitch(mode, onChange) {
  const wrap = document.createElement("div");
  wrap.className = "rail-switch";

  const directBtn = document.createElement("button");
  directBtn.type = "button";
  directBtn.className = "rail-option direct" + (mode !== "proxy" ? " active" : "");
  directBtn.textContent = "Direct";
  directBtn.addEventListener("click", () => onChange("direct"));

  const tunnelBtn = document.createElement("button");
  tunnelBtn.type = "button";
  tunnelBtn.className = "rail-option tunnel" + (mode === "proxy" ? " active" : "");
  tunnelBtn.textContent = "Tunnel";
  tunnelBtn.addEventListener("click", () => onChange("proxy"));

  wrap.append(directBtn, tunnelBtn);
  return wrap;
}

async function setDomainMode(domain, mode) {
  await send({ type: "SET_DOMAIN_MODE", domain, mode });
  await refresh();
}

function renderRulesView() {
  const list = $("ruleList");
  list.innerHTML = "";

  const rules = state.rules || [];
  $("rulesEmpty").hidden = rules.length > 0;
  list.hidden = rules.length === 0;

  rules.forEach((rule, idx) => {
    list.appendChild(buildRuleRow(rule, idx, rules.length));
  });
}

function buildRuleRow(rule, idx, total) {
  const li = document.createElement("li");
  li.className = "rule-row";

  const input = document.createElement("input");
  input.className = "rule-pattern";
  input.value = rule.pattern;
  input.spellcheck = false;
  input.addEventListener("change", () => {
    send({ type: "UPDATE_RULE", id: rule.id, pattern: input.value.trim(), mode: rule.mode }).then(refresh);
  });

  const rail = buildRailSwitch(rule.mode, (mode) => {
    send({ type: "UPDATE_RULE", id: rule.id, pattern: rule.pattern, mode }).then(refresh);
  });

  const actions = document.createElement("div");
  actions.className = "rule-actions";

  const up = document.createElement("button");
  up.className = "icon-btn up";
  up.type = "button";
  up.textContent = "▲";
  up.disabled = idx === 0;
  up.title = "Higher priority";
  up.addEventListener("click", () => send({ type: "MOVE_RULE", id: rule.id, direction: "up" }).then(refresh));

  const down = document.createElement("button");
  down.className = "icon-btn down";
  down.type = "button";
  down.textContent = "▼";
  down.disabled = idx === total - 1;
  down.title = "Lower priority";
  down.addEventListener("click", () => send({ type: "MOVE_RULE", id: rule.id, direction: "down" }).then(refresh));

  const del = document.createElement("button");
  del.className = "icon-btn delete";
  del.type = "button";
  del.textContent = "✕";
  del.title = "Delete rule";
  del.addEventListener("click", () => send({ type: "DELETE_RULE", id: rule.id }).then(refresh));

  actions.append(up, down, del);
  li.append(input, rail, actions);
  return li;
}

function renderFooter() {
  $("targetLabel").textContent = `${state.proxyHost}:${state.proxyPort}`;
}

// ---------------------------------------------------------------------
// Event wiring
// ---------------------------------------------------------------------

document.querySelectorAll(".tab-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".tab-btn").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    const tab = btn.dataset.tab;
    $("view-page").hidden = tab !== "page";
    $("view-rules").hidden = tab !== "rules";
  });
});

$("masterSwitch").addEventListener("click", async () => {
  const enabled = $("masterSwitch").getAttribute("aria-checked") !== "true";
  await send({ type: "SET_ENABLED", enabled });
  await refresh();
});

$("addRuleForm").addEventListener("submit", async (e) => {
  e.preventDefault();
  const pattern = $("newPattern").value.trim();
  const mode = $("newMode").value;
  if (!pattern) return;
  await send({ type: "ADD_RULE", pattern, mode });
  $("newPattern").value = "";
  await refresh();
});

$("reloadTabBtn").addEventListener("click", async () => {
  if (currentTabId == null) return;
  await send({ type: "CLEAR_TAB_FAILURES", tabId: currentTabId });
  await send({ type: "RELOAD_TAB", tabId: currentTabId });
  window.close();
});

$("targetBtn").addEventListener("click", () => {
  const editor = $("targetEditor");
  editor.hidden = !editor.hidden;
  if (!editor.hidden) {
    $("targetHost").value = state.proxyHost;
    $("targetPort").value = state.proxyPort;
  }
});

$("targetSave").addEventListener("click", async () => {
  const host = $("targetHost").value.trim() || "127.0.0.1";
  const port = $("targetPort").value.trim() || "40000";
  await send({ type: "SET_PROXY_TARGET", host, port });
  $("targetEditor").hidden = true;
  await refresh();
});

refresh();
