# LiberationDPI - Self-Healing Deployment Engine

> **Shielding my right to roam the digital world. 🚀**

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/ugseecs/LiberationDPI/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/ugseecs/LiberationDPI/blob/main/LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/ugseecs/LiberationDPI)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)](https://github.com/ugseecs/LiberationDPI)


## What Is This?

This is a one-command Windows deployment engine that installs and manages **Mihomo** (formerly Clash.Meta) as a silent, self-healing local proxy to bypass **Deep Packet Inspection (DPI)** blocks imposed by ISPs and network-level censorship systems.

DPI is a technique used by Internet Service Providers and government-controlled network infrastructure to inspect the content and destination of your traffic, then selectively block or throttle connections to certain websites and services. This tool creates a local tunnel through community-maintained proxy servers that your ISP cannot easily detect or filter, restoring your access to the open internet.

It is built specifically for **Windows users** who want a low-friction, no-configuration solution with a proper system tray UI, an interactive web dashboard, and automatic startup on every boot.

---

## Why It Matters

In many regions, ISPs are legally required or financially incentivized to block access to websites, social platforms, communication tools, and news sources. DPI makes this blocking invisible to the user as your request simply never arrives, or returns a false error. Standard VPNs are increasingly fingerprinted and blocked by the same DPI systems they are meant to bypass.

Mihomo uses modern obfuscated protocols (VLESS, Trojan, Shadowsocks, VMess) over standard HTTPS ports that are indistinguishable from normal encrypted web traffic. This makes it significantly harder for DPI systems to detect and block the tunnel compared to traditional VPN protocols.

This script automates the entire lifecycle:

- Downloads the official Mihomo binary directly from its GitHub releases
- Configures it with multiple community proxy subscription feeds as fallback layers
- Runs it silently in the background with zero terminal windows
- Adds a system tray icon for live management, server switching, and connection diagnostics
- Hooks into Windows startup so the tunnel is always available after a reboot
- Provides a built-in web control panel (MetaCubeXD) at `http://127.0.0.1:9090/ui`

---

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or later (built into all modern Windows versions)
- Administrator privileges (the script auto-requests elevation)
- An active internet connection for the initial download

---

## Quick Start

### Option 1: Run directly from GitHub (recommended, no download needed)

Open PowerShell as Administrator and paste this single command:

```powershell
irm https://raw.githubusercontent.com/ugseecs/LiberationDPI/main/deploy-mihomo.ps1 | iex
```

This fetches the latest script from GitHub and runs it immediately in memory without saving a file to your disk first.

### Option 2: Download and run manually

1. Download `deploy-mihomo.ps1` from this repository
2. Right-click it and select **Run with PowerShell**, or open an Administrator PowerShell and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "deploy-mihomo.ps1"
```

---

## Uninstall

To completely remove all components, the binary, the startup hook, and all configuration files, run:

```powershell
irm https://raw.githubusercontent.com/ugseecs/LiberationDPI/main/deploy-mihomo.ps1 | iex -Uninstall
```

Or if you downloaded the file:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "deploy-mihomo.ps1" -Uninstall
```

This performs a clean four-stage removal with zero leftover files.

---

## What the Script Does (Step by Step)

**Consent Gate**
Before touching anything on your system, the script displays a full security and privacy notice explaining the risks of public proxy nodes. You must explicitly type `Y` to continue. Typing `N` exits immediately with zero system modifications.

**Step 1 - Process Cleanup**
Kills any existing Mihomo processes and old tray instances from previous installs to prevent port conflicts.

**Step 2 - Binary Download**
Downloads the official Mihomo `amd64-compatible` release ZIP directly from the MetaCubeX GitHub repository, extracts the executable to `C:\mihomo\`, and removes the archive.

**Step 3 - Logic Layer (Common.ps1)**
Writes a shared PowerShell module to `C:\mihomo\Common.ps1` containing all provider management functions, the YAML config builder, and the tunnel health-check utility. This module is dot-sourced by both the installer and the tray app.

**Step 4 - Tray Application (TrayApp.ps1)**
Writes a full Windows Forms tray application to `C:\mihomo\TrayApp.ps1`. This app runs silently, shows the Internet Globe icon in your system tray, and gives you a right-click menu to switch provider tracks, open the web dashboard, verify the tunnel, browse the install directory, or exit the service.

**Step 5 - Provider Selection Menu**
Presents an interactive terminal menu where you toggle which proxy subscription feeds to enable. You can also paste in a custom subscription URL. Enabled providers are merged into the Mihomo YAML config with automatic health checks every 10 minutes and feed refresh every hour.

**Step 6 - Startup Hook**
Creates a VBScript launcher (`LaunchMihomoTray.vbs`) in your Windows Startup folder so the tray app launches silently on every login with no visible terminal window.

---

## Browser Setup: ZeroOmega / SwitchyOmega

The proxy runs locally on `127.0.0.1:40000` (SOCKS5). You do **not** want to route all your browser traffic through it. Only blocked sites should go through the proxy. This is faster, more private, and avoids unnecessary load on public nodes.

### Setup Steps

1. Install the **[ZeroOmega](https://chromewebstore.google.com/detail/proxy-switchyomega-3-zero/pfnededegaaopdmhkdmcofjmoldfiped?hl=en)** extension from your browser's extension store (Chrome, Edge, or Firefox)
2. Open the extension **Options**
3. Click **New Profile**, name it `Mihomo Core`, set type to **Proxy Profile**
4. Set:
   - Protocol: `SOCKS5`
   - Server: `127.0.0.1`
   - Port: `40000`
5. Click **Apply Changes**
6. Go to the **Auto Switch** profile tab in the left sidebar
7. Add a rule:
   - Condition Type: `Wildcard`
   - Condition Details: `*.blocked-site.com` (replace with the domain you need)
   - Profile: `Mihomo Core`
8. Click **Apply Changes**
9. Click the ZeroOmega icon in your browser toolbar and select **Auto Switch**

All other traffic goes directly through your ISP as normal. Only the domains you specify get tunneled.

---

## IMPORTANT: Only Route What Is Blocked

**Do not route your entire browser traffic through this proxy.**

Many websites load resources from third-party domains (fonts, CDNs, APIs, analytics, payment processors). If a blocked site is not loading correctly even after you added its domain to ZeroOmega, some of those third-party resources are also being blocked by your ISP.

**How to find and fix this:**

1. Click the **ZeroOmega extension icon** in your browser toolbar
2. A dropdown will show **failed resources** that were blocked or did not load
3. For each failed resource domain listed, add a new **Wildcard rule** in your Auto Switch profile pointing to `Mihomo Core`
4. Click **Apply Changes** and reload the page

Repeat this until the site loads fully. This keeps your proxy usage minimal and targeted, which is better for your privacy and for the health of the shared public node pools.

---

## Security and Privacy Notice

This tool uses **free, community-maintained public proxy nodes**. Please read and understand the following before use:

**What node operators can potentially see:**
- The destination IP addresses or domain names your requests are going to (DNS metadata)
- The volume and timing of your traffic

**What node operators cannot see:**
- The content of any HTTPS connection (your passwords, messages, session tokens)
- Anything encrypted under standard TLS, which covers virtually every modern website

**Rules to follow:**
- Do not use public nodes as a global proxy for sensitive accounts such as banking or primary email
- Do not input credentials on HTTP (non-HTTPS) sites while routed through a public node
- Use Auto Switch mode in ZeroOmega so only blocked domains go through the proxy
- If you need higher security for sensitive tasks, use a paid, trusted VPN provider instead

---

## Proxy Provider Sources

| Provider | Status | Description |
|---|---|---|
| Awesome-VPN CDN | Enabled by default | Stable CDN mirror, community-aggregated pool |
| Ermaozi GitHub | Enabled by default | Hourly-updated scraper pool, high redundancy |
| Anaer Automations | Enabled by default | GitHub Actions automated scraper, reliable uptime |
| Vxiaov Mirror | Optional | Heavy VLESS/Trojan node set, good for strict networks |
| Aiboboxx Free Sub | Optional | Long-standing free node maintainer |
| Ruk1ng001 Track | Optional | Daily-updated mixed-protocol track |

You can add your own Clash-compatible subscription URL during setup or later via the tray menu.

---

## File Structure After Install

```
C:\mihomo\
    mihomo.exe          # Mihomo core binary
    config.yaml         # Generated Clash/Mihomo configuration
    providers.json      # Your saved provider selection
    Common.ps1          # Shared logic module (providers, config builder, health check)
    TrayApp.ps1         # Windows Forms tray application
    providers\          # Cached proxy node lists from subscription feeds
    ui\                 # MetaCubeXD web dashboard files

%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
    LaunchMihomoTray.vbs    # Silent startup launcher
```

---

## Web Dashboard

The MetaCubeXD web dashboard is available at:

```
http://127.0.0.1:9090/ui
```

Open this in any browser while Mihomo is running. It gives you a full visual interface to inspect connected nodes, switch between proxy groups, view real-time traffic, and check latency on individual servers.

You can also open it directly from the system tray by right-clicking the globe icon and selecting **Open Web Control Panel**.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Author

**Usama Gulzar**

---

*Shielding my right to roam the digital world. 🚀*
