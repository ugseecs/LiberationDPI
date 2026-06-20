// background.js — LiberationDPI Switch
//
// Responsibilities:
//  1. Watch every tab for failed resource loads (net::ERR_* events) and keep
//     a per-tab, per-hostname failure count, reflected on the toolbar badge.
//  2. Store user rules (pattern -> "proxy" | "direct") and rebuild a PAC
//     script whenever they change, so Chrome's networking stack (not just
//     the extension) honors them.
//  3. Answer messages from the popup UI.

const DEFAULTS = {
  proxyEnabled: true,
  proxyHost: "127.0.0.1",
  proxyPort: 40000, // matches $MixedPort in the LiberationDPI deploy script
  rules: [] // [{ id, pattern, mode }]
};

// In-memory fallback if chrome.storage.session isn't available.
const memoryTabFailures = new Map(); // tabId -> Map(hostname -> count)

function genId() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

async function getSettings() {
  const stored = await chrome.storage.local.get(DEFAULTS);
  return { ...DEFAULTS, ...stored };
}

async function saveSettings(partial) {
  await chrome.storage.local.set(partial);
}

// ---------------------------------------------------------------------
// Per-tab failure tracking
// ---------------------------------------------------------------------

function hasSessionStorage() {
  return typeof chrome.storage.session !== "undefined";
}

async function getTabFailures(tabId) {
  if (hasSessionStorage()) {
    const key = `fails_${tabId}`;
    const result = await chrome.storage.session.get(key);
    return result[key] || {};
  }
  const m = memoryTabFailures.get(tabId);
  return m ? Object.fromEntries(m) : {};
}

async function setTabFailures(tabId, obj) {
  if (hasSessionStorage()) {
    await chrome.storage.session.set({ [`fails_${tabId}`]: obj });
  } else {
    memoryTabFailures.set(tabId, new Map(Object.entries(obj)));
  }
}

async function clearTabFailures(tabId) {
  if (hasSessionStorage()) {
    await chrome.storage.session.remove(`fails_${tabId}`);
  } else {
    memoryTabFailures.delete(tabId);
  }
  await updateBadge(tabId);
}

async function recordFailure(tabId, hostname) {
  const fails = await getTabFailures(tabId);
  fails[hostname] = (fails[hostname] || 0) + 1;
  await setTabFailures(tabId, fails);
  await updateBadge(tabId);
}

async function updateBadge(tabId) {
  const fails = await getTabFailures(tabId);
  const distinctDomains = Object.keys(fails).length;
  try {
    if (distinctDomains === 0) {
      await chrome.action.setBadgeText({ tabId, text: "" });
    } else {
      await chrome.action.setBadgeText({ tabId, text: String(distinctDomains) });
      await chrome.action.setBadgeBackgroundColor({ tabId, color: "#F0B429" });
    }
  } catch (e) {
    // Tab may have closed mid-update; safe to ignore.
  }
}

function extractHostname(url) {
  try {
    const u = new URL(url);
    if (u.protocol !== "http:" && u.protocol !== "https:") return null;
    return u.hostname;
  } catch (e) {
    return null;
  }
}

chrome.webRequest.onErrorOccurred.addListener(
  (details) => {
    if (details.tabId === undefined || details.tabId < 0) return;
    // Ignore loads cancelled by the user (e.g. navigating away quickly) —
    // these aren't blocking/censorship and would just create noise.
    if (details.error === "net::ERR_ABORTED") return;
    const hostname = extractHostname(details.url);
    if (!hostname) return;
    recordFailure(details.tabId, hostname);
  },
  { urls: ["<all_urls>"] }
);

// Reset counters on every fresh top-level navigation.
chrome.webNavigation.onBeforeNavigate.addListener((details) => {
  if (details.frameId === 0) {
    clearTabFailures(details.tabId);
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  clearTabFailures(tabId);
});

// ---------------------------------------------------------------------
// Rule matching + PAC generation
// ---------------------------------------------------------------------

function patternToRegExp(pattern) {
  // Mirrors PAC's shExpMatch glob semantics: "*" and "?" only, case-sensitive
  // host comparison done in lowercase for predictability.
  const escaped = pattern
    .toLowerCase()
    .replace(/[.+^${}()|[\]\\]/g, "\\$&")
    .replace(/\*/g, ".*")
    .replace(/\?/g, ".");
  return new RegExp(`^${escaped}$`);
}

function effectiveModeForHost(hostname, rules) {
  const h = hostname.toLowerCase();
  for (const rule of rules) {
    if (patternToRegExp(rule.pattern).test(h)) return rule.mode;
  }
  return "direct";
}

function buildPacScript(rules, proxyHost, proxyPort) {
  // Patterns are passed through verbatim; shExpMatch in PAC uses the same
  // glob syntax ("*" / "?") as our local matcher above.
  const safeRules = rules.map((r) => ({ pattern: r.pattern, mode: r.mode }));
  return [
    "function FindProxyForURL(url, host) {",
    `  var rules = ${JSON.stringify(safeRules)};`,
    "  var h = host.toLowerCase();",
    "  for (var i = 0; i < rules.length; i++) {",
    "    if (shExpMatch(h, rules[i].pattern.toLowerCase())) {",
    "      if (rules[i].mode === 'proxy') {",
    `        return "SOCKS5 ${proxyHost}:${proxyPort}; DIRECT";`,
    "      }",
    "      return 'DIRECT';",
    "    }",
    "  }",
    "  return 'DIRECT';",
    "}"
  ].join("\n");
}

async function rebuildProxy() {
  const { proxyEnabled, proxyHost, proxyPort, rules } = await getSettings();

  if (!proxyEnabled) {
    await chrome.proxy.settings.set({ value: { mode: "direct" }, scope: "regular" });
    return;
  }

  const pacScript = buildPacScript(rules, proxyHost, proxyPort);
  await chrome.proxy.settings.set({
    value: { mode: "pac_script", pacScript: { data: pacScript } },
    scope: "regular"
  });
}

chrome.runtime.onInstalled.addListener(() => rebuildProxy());
chrome.runtime.onStartup.addListener(() => rebuildProxy());

// ---------------------------------------------------------------------
// Message API for the popup
// ---------------------------------------------------------------------

async function handleMessage(message) {
  const settings = await getSettings();

  switch (message.type) {
    case "GET_STATE": {
      const fails = await getTabFailures(message.tabId);
      const hostname = message.tabUrl ? extractHostname(message.tabUrl) : null;
      const failedDomains = Object.entries(fails)
        .map(([domain, count]) => ({
          domain,
          count,
          mode: effectiveModeForHost(domain, settings.rules),
          hasExplicitRule: settings.rules.some(
            (r) => r.pattern.toLowerCase() === domain.toLowerCase()
          )
        }))
        .sort((a, b) => b.count - a.count);
      return {
        proxyEnabled: settings.proxyEnabled,
        proxyHost: settings.proxyHost,
        proxyPort: settings.proxyPort,
        rules: settings.rules,
        failedDomains,
        activeHostname: hostname
      };
    }

    case "SET_DOMAIN_MODE": {
      const domain = message.domain.toLowerCase();
      const rules = [...settings.rules];
      const idx = rules.findIndex((r) => r.pattern.toLowerCase() === domain);
      if (idx >= 0) {
        rules[idx] = { ...rules[idx], mode: message.mode };
        // Move it to the front so an exact host override always wins
        // over a broader wildcard rule added later.
        const [r] = rules.splice(idx, 1);
        rules.unshift(r);
      } else {
        rules.unshift({ id: genId(), pattern: domain, mode: message.mode });
      }
      await saveSettings({ rules });
      await rebuildProxy();
      return { ok: true };
    }

    case "ADD_RULE": {
      const pattern = (message.pattern || "").trim();
      if (!pattern) return { ok: false, error: "Pattern cannot be empty." };
      const rules = [...settings.rules, { id: genId(), pattern, mode: message.mode || "proxy" }];
      await saveSettings({ rules });
      await rebuildProxy();
      return { ok: true };
    }

    case "UPDATE_RULE": {
      const rules = settings.rules.map((r) =>
        r.id === message.id ? { ...r, pattern: message.pattern, mode: message.mode } : r
      );
      await saveSettings({ rules });
      await rebuildProxy();
      return { ok: true };
    }

    case "DELETE_RULE": {
      const rules = settings.rules.filter((r) => r.id !== message.id);
      await saveSettings({ rules });
      await rebuildProxy();
      return { ok: true };
    }

    case "MOVE_RULE": {
      const rules = [...settings.rules];
      const idx = rules.findIndex((r) => r.id === message.id);
      if (idx < 0) return { ok: false };
      const swapWith = message.direction === "up" ? idx - 1 : idx + 1;
      if (swapWith < 0 || swapWith >= rules.length) return { ok: false };
      [rules[idx], rules[swapWith]] = [rules[swapWith], rules[idx]];
      await saveSettings({ rules });
      await rebuildProxy();
      return { ok: true };
    }

    case "SET_ENABLED": {
      await saveSettings({ proxyEnabled: !!message.enabled });
      await rebuildProxy();
      return { ok: true };
    }

    case "SET_PROXY_TARGET": {
      const port = parseInt(message.port, 10);
      await saveSettings({
        proxyHost: message.host || DEFAULTS.proxyHost,
        proxyPort: Number.isFinite(port) ? port : DEFAULTS.proxyPort
      });
      await rebuildProxy();
      return { ok: true };
    }

    case "RELOAD_TAB": {
      await chrome.tabs.reload(message.tabId);
      return { ok: true };
    }

    case "CLEAR_TAB_FAILURES": {
      await clearTabFailures(message.tabId);
      return { ok: true };
    }

    default:
      return { ok: false, error: "Unknown message type" };
  }
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  handleMessage(message).then(sendResponse);
  return true; // keep the message channel open for the async response
});
