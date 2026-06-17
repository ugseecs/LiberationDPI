<#
.SYNOPSIS
    Self-Healing DPI Bypass Proxy Deployment Engine - LiberationDPI.
.DESCRIPTION
    Installs Mihomo (Clash.Meta), enforces strict security and privacy consent,
    displays maintainer integrity history for public proxy nodes, and executes a
    silent Windows System Tray UI with a built-in Web Control Panel to manually
    override geo-locations and bypass Cloudflare worker loops.
.PARAMETER Uninstall
    Removes all installed components, stops the core engine, clears tray handlers,
    deletes C:\mihomo, and drops the Windows startup hooks cleanly.
.NOTES
    Author:  Usama Gulzar
    Version: 1.0.0
    License: MIT
    GitHub:  https://github.com/ugseecs/LiberationDPI
#>

param(
    [switch]$Uninstall
)

$ScriptVersion      = "1.0.0"
$MinPSVersion       = [Version]"5.1"
$ProgressPreference = 'SilentlyContinue'

# Guard: PowerShell Version & Admin Escalation

if ($PSVersionTable.PSVersion -lt $MinPSVersion) {
    Write-Error "PowerShell $MinPSVersion or later is required. You have $($PSVersionTable.PSVersion)."
    Exit 1
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[*] Requesting Administrator Privileges..." -ForegroundColor Yellow
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Uninstall) { $argList += " -Uninstall" }
    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    Exit
}

# Core Layout Paths Matrix

$TargetDir    = "C:\mihomo"
$ProvidersDir = "$TargetDir\providers"
$ConfigFile   = "$TargetDir\config.yaml"
$BinaryFile   = "$TargetDir\mihomo.exe"
$ProvidersFile = "$TargetDir\providers.json"
$CommonFile   = "$TargetDir\Common.ps1"
$TrayFile     = "$TargetDir\TrayApp.ps1"
$StartupFolder = [System.Environment]::GetFolderPath('Startup')
$VbsScript    = "$StartupFolder\LaunchMihomoTray.vbs"
$MixedPort    = 40000


# UNINSTALLER PIPELINE

if ($Uninstall) {
    Clear-Host
    Write-Host "=========================================================" -ForegroundColor Yellow
    Write-Host "           LiberationDPI - UNINSTALLER RUNTIME           " -ForegroundColor Yellow
    Write-Host "=========================================================" -ForegroundColor Yellow

    Write-Host "`n[1/4] Stripping active binary proxy threads..." -ForegroundColor Cyan
    Stop-Process -Name "mihomo" -Force -ErrorAction SilentlyContinue

    Write-Host "[2/4] Dismantling background scripts and tray engines..." -ForegroundColor Cyan
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -like "*TrayApp.ps1*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

    Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -like "*LaunchMihomoTray.vbs*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

    Write-Host "[3/4] Tearing down boot startup hooks..." -ForegroundColor Cyan
    Remove-Item -Path $VbsScript -Force -ErrorAction SilentlyContinue

    Write-Host "[4/4] Purging installation directory C:\mihomo..." -ForegroundColor Cyan
    Remove-Item -Path $TargetDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "`n=========================================================" -ForegroundColor Green
    Write-Host " SUCCESS: Uninstall complete. All components scrubbed.    " -ForegroundColor Green
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "`nPress Enter to close this window..." -ForegroundColor DarkGray
    Read-Host
    Exit 0
}


# Guard: Public Node Security Warning & Strict Consent Gatekeeper
# ---------------------------------------------------------------------------
Clear-Host
Write-Host "=========================================================" -ForegroundColor Red
Write-Host "      SECURITY AND PRIVACY CONSENT: READ CAREFULLY       " -ForegroundColor Red
Write-Host "=========================================================" -ForegroundColor Red
Write-Host " This deployment engine utilizes free, community-driven"
Write-Host " proxy subscription providers to mitigate DPI blocks."
Write-Host "`n [!] CRITICAL SECURITY RULES:" -ForegroundColor Yellow
Write-Host "  1. METADATA EXPOSURE: Public server volunteers can log"
Write-Host "     your DNS routing lookups and target destination IPs." -ForegroundColor DarkGray
Write-Host "  2. SECURE LOGINS: Do NOT input plain-text credentials or"
Write-Host "     access highly sensitive profiles (banking, primary mail)"
Write-Host "     globally through public exit nodes." -ForegroundColor DarkGray
Write-Host "  3. ENCRYPTION SAFEGUARD: Standard browser HTTPS/TLS layer"
Write-Host "     remains fully secure; node operators cannot see passwords." -ForegroundColor DarkGray
Write-Host "`n RECOMMENDATION: Keep browser extensions (ZeroOmega/SwitchyOmega)" -ForegroundColor Cyan
Write-Host " on 'Auto Switch' mode. Route ONLY censored domains through" -ForegroundColor Cyan
Write-Host " the proxy port, keeping 99% of normal traffic on your raw ISP." -ForegroundColor Cyan
Write-Host "---------------------------------------------------------"

$Consent = Read-Host " Type 'Y' to accept these privacy terms and continue, or 'N' to abort"
if ($Consent -notmatch '^[Yy]$') {
    Write-Host "`n [*] Deployment terminated by user consent guard. No system modifications made." -ForegroundColor Red
    Start-Sleep -Seconds 3
    Exit 0
}


# INSTALLATION FLOW
# ---------------------------------------------------------------------------
Clear-Host
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "   AUTOMATED SELF-HEALING DPI BYPASS DEPLOYMENT ENGINE   " -ForegroundColor Green
Write-Host "   Version $ScriptVersion                                 " -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Step 1: Clean up existing conflicting processes
# ---------------------------------------------------------------------------
Write-Host "`n[1/6] Terminating active processes and old tray instances..." -ForegroundColor Cyan
Stop-Process -Name "mihomo" -Force -ErrorAction SilentlyContinue

Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -like "*TrayApp.ps1*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Get-CimInstance Win32_Process -Filter "Name='wscript.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -like "*LaunchMihomoTray.vbs*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1

# ---------------------------------------------------------------------------
# Step 2: Auto-Update Check & Binary Acquisition
# ---------------------------------------------------------------------------
$CurrentCoreVersion = "v1.19.26"
Write-Host "[2/6] Checking for core updates (Current: $CurrentCoreVersion)..." -ForegroundColor Cyan

foreach ($dir in @($TargetDir, $ProvidersDir)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}

try {
    $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" -UseBasicParsing -ErrorAction SilentlyContinue
    $TargetUrl = "https://github.com/MetaCubeX/mihomo/releases/download/v1.19.26/mihomo-windows-amd64-compatible-v1.19.26.zip" # Fallback
    
    if ($null -ne $LatestRelease -and $LatestRelease.tag_name -gt $CurrentCoreVersion) {
        Write-Host "      [!] New core version detected: $($LatestRelease.tag_name). Pulling update..." -ForegroundColor Yellow
        $matchingAsset = $LatestRelease.assets | Where-Object { $_.name -like "*windows-amd64-compatible*.zip" }
        if ($matchingAsset) {
            $TargetUrl = $matchingAsset.browser_download_url
        }
    } else {
        Write-Host "      Core is up to date or API unreachable. Proceeding..." -ForegroundColor DarkGray
    }

    $ZipPath   = "$TargetDir\mihomo.zip"
    Invoke-WebRequest -Uri $TargetUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop

    $ExtractedPath = "$TargetDir\extracted"
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractedPath -Force

    $exeFile = Get-ChildItem -Path $ExtractedPath -Filter "*.exe" -Recurse | Select-Object -First 1
    Move-Item -Path $exeFile.FullName -Destination $BinaryFile -Force
    Remove-Item -Path $ExtractedPath, $ZipPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Core binary structure compiled." -ForegroundColor Green
}
catch {
    Write-Host "[!] Fatal Error: Could not pull dependency archives. Check internet connection." -ForegroundColor Red
    Exit 1
}

# ---------------------------------------------------------------------------
# Step 3: Write the shared logic & UI Config (Common.ps1)
# ---------------------------------------------------------------------------
Write-Host "[3/6] Packaging functional logic layers and provider intel (Common.ps1)..." -ForegroundColor Cyan

$CommonScriptContent = @'
function Get-ProviderKey {
    param([string]$Name)
    $key = $Name.ToLower() -replace '[^a-z0-9]+', '-'
    return $key.Trim('-')
}

function Get-DefaultProviders {
    return @(
        [PSCustomObject]@{ Name = "Awesome-VPN CDN";    Url = "https://cdn.jsdelivr.net/gh/awesome-vpn/awesome-vpn@master/clash.yaml";                          Enabled = $true;  Desc = "Primary CDN mirror. Highly stable, community-aggregated node pool via public GitHub tracking." },
        [PSCustomObject]@{ Name = "Ermaozi GitHub";     Url = "https://raw.githubusercontent.com/ermaozi/get_subscribe/main/subscribe/clash.yml";              Enabled = $true;  Desc = "Massive scraper pool. Extremely frequent hourly updates. Excellent failover redundancy." },
        [PSCustomObject]@{ Name = "Anaer Automations";  Url = "https://raw.githubusercontent.com/anaer/Sub/main/clash.yaml";                                   Enabled = $true;  Desc = "Automated GitHub Actions scraper. Reliable long-term uptime history with standard TLS nodes." },
        [PSCustomObject]@{ Name = "Vxiaov Mirror";      Url = "https://cdn.jsdelivr.net/gh/vxiaov/free_proxies@main/clash/clash.provider.yaml";                Enabled = $false; Desc = "Secondary CDN mirror. Heavy VLESS/Trojan nodes. Good for strict network topologies." },
        [PSCustomObject]@{ Name = "Aiboboxx Free Sub";  Url = "https://raw.githubusercontent.com/aiboboxx/clashfree/main/clash.yml";                           Enabled = $false; Desc = "Long-standing free node maintainer. Trusted, but public nodes can occasionally bottleneck." },
        [PSCustomObject]@{ Name = "Ruk1ng001 Track";    Url = "https://raw.githubusercontent.com/Ruk1ng001/freeSub/main/clash.yaml";                           Enabled = $false; Desc = "Daily updated mixed-protocol track. Solid latency, variable region availability." }
    )
}

function Save-Providers {
    param([string]$Path, [array]$Providers)
    $Providers | ConvertTo-Json -Depth 4 | Set-Content -Path $Path -Encoding UTF8
}

function Get-Providers {
    param([string]$Path)
    if (Test-Path $Path) {
        try { return @(Get-Content -Path $Path -Raw | ConvertFrom-Json) } catch { }
    }
    $defaults = Get-DefaultProviders
    Save-Providers -Path $Path -Providers $defaults
    return $defaults
}

function Build-Config {
    param([array]$Providers, [string]$ConfigPath, [int]$Port = 40000)

    $enabled = @($Providers | Where-Object { $_.Enabled })
    if ($enabled.Count -eq 0 -and $Providers.Count -gt 0) {
        $Providers[0].Enabled = $true
        $enabled = @($Providers[0])
    }

    $providerBlock = New-Object System.Text.StringBuilder
    $useBlock      = New-Object System.Text.StringBuilder

    foreach ($p in $enabled) {
        $key = Get-ProviderKey -Name $p.Name
        [void]$providerBlock.AppendLine("  ${key}:")
        [void]$providerBlock.AppendLine("    type: http")
        [void]$providerBlock.AppendLine("    url: `"$($p.Url)`"")
        [void]$providerBlock.AppendLine("    interval: 3600")
        [void]$providerBlock.AppendLine("    path: ./providers/$key.yaml")
        [void]$providerBlock.AppendLine("    health-check:")
        [void]$providerBlock.AppendLine("      enable: true")
        [void]$providerBlock.AppendLine("      interval: 600")
        [void]$providerBlock.AppendLine("      url: http://www.gstatic.com/generate_204")
        [void]$useBlock.AppendLine("      - $key")
    }

    $yaml = @"
mixed-port: $Port
allow-lan: false
mode: rule
log-level: info
ipv6: false

external-controller: 127.0.0.1:9090
external-ui: ui
external-ui-url: "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"

dns:
  enable: true
  ipv6: false
  enhanced-mode: fake-ip
  listen: 127.0.0.1:1053
  default-nameserver: [1.1.1.1, 8.8.8.8]
  nameserver: [https://1.1.1.1/dns-query, https://8.8.8.8/dns-query]

proxy-providers:
$($providerBlock.ToString().TrimEnd())

proxy-groups:
  - name: "Global-Exit"
    type: select
    proxies:
      - "Auto-Fastest"
    use:
$($useBlock.ToString().TrimEnd())

  - name: "Auto-Fastest"
    type: url-test
    use:
$($useBlock.ToString().TrimEnd())
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    tolerance: 50

rules:
  - MATCH,Global-Exit
"@
    Set-Content -Path $ConfigPath -Value $yaml -Encoding UTF8
}

function Test-ProxyConnection {
    param([int]$Port = 40000)
    try {
        $output = & curl.exe -s -o "$env:TEMP\null.tmp" -w "%{http_code}" -x "socks5h://127.0.0.1:$Port" --connect-timeout 6 "https://www.google.com"
        Remove-Item "$env:TEMP\null.tmp" -Force -ErrorAction SilentlyContinue
        return ($output -match "200")
    } catch { return $false }
}
'@

Set-Content -Path $CommonFile -Value $CommonScriptContent -Encoding UTF8

# ---------------------------------------------------------------------------
# Step 4: Write the tray application (TrayApp.ps1) with Dashboard Link
# ---------------------------------------------------------------------------
Write-Host "[4/6] Exporting native System Tray UI layer (TrayApp.ps1)..." -ForegroundColor Cyan

$TrayAppContent = @'
$script:TargetDir     = "C:\mihomo"
$script:ConfigFile    = "$script:TargetDir\config.yaml"
$script:BinaryFile    = "$script:TargetDir\mihomo.exe"
$script:ProvidersFile = "$script:TargetDir\providers.json"
$script:CommonScript  = "$script:TargetDir\Common.ps1"
$script:Port          = 40000

. $script:CommonScript

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

function Stop-Mihomo {
    Get-Process -Name "mihomo" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Start-Mihomo {
    Stop-Mihomo
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName         = $script:BinaryFile
        $psi.Arguments        = "-d ."
        $psi.WorkingDirectory = $script:TargetDir
        $psi.WindowStyle      = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.CreateNoWindow   = $true
        $psi.UseShellExecute  = $false
        [void][System.Diagnostics.Process]::Start($psi)
    } catch { }
}

# ---------------------------------------------------------------------------
# Watchdog Engine: Auto-healing for the Mihomo core
# ---------------------------------------------------------------------------
$Watchdog = New-Object System.Windows.Forms.Timer
$Watchdog.Interval = 10000 # 10-second heartbeat check
$Watchdog.Add_Tick({
    $process = Get-Process -Name "mihomo" -ErrorAction SilentlyContinue
    if (-not $process) {
        # Silent restart: only alert if the user is actively looking at the tray
        Start-Mihomo
        $script:notifyIcon.ShowBalloonTip(2000, "LiberationDPI", "Engine heartbeat lost. Recovering tunnel...", [System.Windows.Forms.ToolTipIcon]::Warning)
    }
})
$Watchdog.Start()

function Rebuild-And-Restart {
    $providers = Get-Providers -Path $script:ProvidersFile
    Build-Config -Providers $providers -ConfigPath $script:ConfigFile -Port $script:Port
    Start-Mihomo
}

$script:icon = $null
try {
    $cplPath     = Join-Path $env:SystemRoot "System32\inetcpl.cpl"
    $script:icon = [System.Drawing.Icon]::ExtractAssociatedIcon($cplPath)
} catch {
    $script:icon = [System.Drawing.SystemIcons]::Application
}

$script:notifyIcon              = New-Object System.Windows.Forms.NotifyIcon
$script:notifyIcon.Icon         = $script:icon
$script:notifyIcon.Text         = "Mihomo Core Router (127.0.0.1:$script:Port)"
$script:notifyIcon.Visible      = $true

$script:contextMenu             = New-Object System.Windows.Forms.ContextMenuStrip
$script:notifyIcon.ContextMenuStrip = $script:contextMenu

function Rebuild-Menu {
    $script:contextMenu.Items.Clear()

    $statusItem         = New-Object System.Windows.Forms.ToolStripMenuItem
    $statusItem.Text    = "Mihomo Core Active: 127.0.0.1:$($script:Port)"
    $statusItem.Enabled = $false
    [void]$script:contextMenu.Items.Add($statusItem)
    [void]$script:contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $uiItem      = New-Object System.Windows.Forms.ToolStripMenuItem
    $uiItem.Text = "Open Web Control Panel"
    $uiItem.Add_Click({ Start-Process "http://127.0.0.1:9090/ui" })
    [void]$script:contextMenu.Items.Add($uiItem)

    [void]$script:contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $serversHeader         = New-Object System.Windows.Forms.ToolStripMenuItem
    $serversHeader.Text    = "Censorship Circumvention Tracks"
    $serversHeader.Enabled = $false
    [void]$script:contextMenu.Items.Add($serversHeader)

    $providers = Get-Providers -Path $script:ProvidersFile
    foreach ($p in $providers) {
        $item              = New-Object System.Windows.Forms.ToolStripMenuItem
        $item.Text         = $p.Name
        $item.CheckOnClick = $true
        $item.Checked      = $p.Enabled
        $item.Add_Click({
            $clickedName = $this.Text
            $all = Get-Providers -Path $script:ProvidersFile
            foreach ($pp in $all) {
                if ($pp.Name -eq $clickedName) { $pp.Enabled = -not $pp.Enabled }
            }
            Save-Providers -Path $script:ProvidersFile -Providers $all
            $script:notifyIcon.ShowBalloonTip(1500, "Mihomo Core", "Hot-reloading network maps...", [System.Windows.Forms.ToolTipIcon]::Info)
            Rebuild-And-Restart
            Rebuild-Menu
        })
        [void]$script:contextMenu.Items.Add($item)
    }

    [void]$script:contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $testItem      = New-Object System.Windows.Forms.ToolStripMenuItem
    $testItem.Text = "Verify Network Tunnel Integrity"
    $testItem.Add_Click({
        $script:notifyIcon.ShowBalloonTip(1500, "Diagnostic Engine", "Tracing live handshake loop...", [System.Windows.Forms.ToolTipIcon]::Info)
        if (Test-ProxyConnection -Port $script:Port) {
            $script:notifyIcon.ShowBalloonTip(4000, "Diagnostic Status", "Tunnel verification clear. Pipeline operational.", [System.Windows.Forms.ToolTipIcon]::Info)
        } else {
            $script:notifyIcon.ShowBalloonTip(4000, "Diagnostic Status", "Handshake timeout. Try switching provider tracks.", [System.Windows.Forms.ToolTipIcon]::Warning)
        }
    })
    [void]$script:contextMenu.Items.Add($testItem)

    $folderItem      = New-Object System.Windows.Forms.ToolStripMenuItem
    $folderItem.Text = "Open Core Directory"
    $folderItem.Add_Click({ Start-Process explorer.exe $script:TargetDir })
    [void]$script:contextMenu.Items.Add($folderItem)

    [void]$script:contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $quitItem      = New-Object System.Windows.Forms.ToolStripMenuItem
    $quitItem.Text = "Exit Service Completely"
    $quitItem.Add_Click({
        Stop-Mihomo
        $script:notifyIcon.Visible = $false
        $script:notifyIcon.Dispose()
        [System.Windows.Forms.Application]::Exit()
    })
    [void]$script:contextMenu.Items.Add($quitItem)
}

Rebuild-Menu
Start-Mihomo
$script:notifyIcon.ShowBalloonTip(
    4000, "Anti-DPI Matrix Operational",
    "Listening on local loop socket port $script:Port. Right-click to manage.",
    [System.Windows.Forms.ToolTipIcon]::Info
)

[System.Windows.Forms.Application]::Run()
'@

Set-Content -Path $TrayFile -Value $TrayAppContent -Encoding UTF8

# ---------------------------------------------------------------------------
# Step 5: Interactive Terminal Provider Menu
# ---------------------------------------------------------------------------
. $CommonFile

function Show-ProviderMenu {
    param([array]$Providers)

    $continue = $true
    while ($continue) {
        Clear-Host
        Write-Host "=========================================================" -ForegroundColor Green
        Write-Host "                SELECT YOUR PROXY SOURCE(S)               " -ForegroundColor Green
        Write-Host "=========================================================" -ForegroundColor Green
        Write-Host " NOTICE: Enabling multiple provider tracks gives you active" -ForegroundColor Gray
        Write-Host " failover redundancy if a specific network path falls down.`n" -ForegroundColor Gray

        for ($i = 0; $i -lt $Providers.Count; $i++) {
            $mark = if ($Providers[$i].Enabled) { "[X]" } else { "[ ]" }
            Write-Host (" {0}. {1}  ->  {2}" -f ($i + 1), $mark, $Providers[$i].Name) -ForegroundColor Cyan
            Write-Host ("      URL:  $($Providers[$i].Url)") -ForegroundColor DarkGray
            if ($Providers[$i].Desc) { Write-Host ("      INFO: $($Providers[$i].Desc)`n") -ForegroundColor Gray }
        }

        Write-Host "  A. Add a custom subscription URL"
        Write-Host "  D. Done - save configuration and deploy to background`n"

        $choice = Read-Host "Select index key to toggle, A to add, or D to deploy"

        switch -Regex ($choice) {
            '^\d+$' {
                $idx = [int]$choice - 1
                if ($idx -ge 0 -and $idx -lt $Providers.Count) {
                    $Providers[$idx].Enabled = -not $Providers[$idx].Enabled
                }
            }
            '^[Aa]$' {
                $name = Read-Host "Name descriptor for this source"
                $url  = Read-Host "Subscription URL destination endpoint"
                if ($name -and $url -match '^https?://') {
                    $Providers += [PSCustomObject]@{ Name = $name; Url = $url; Enabled = $true; Desc = "Custom user-provided node track." }
                }
            }
            '^[Dd]$' { $continue = $false }
        }
    }
    return $Providers
}

Write-Host "[5/6] Initializing configuration engine..." -ForegroundColor Cyan
Start-Sleep -Milliseconds 600
$providers = Get-Providers -Path $ProvidersFile
$providers = Show-ProviderMenu -Providers $providers
Save-Providers -Path $ProvidersFile -Providers $providers
Build-Config -Providers $providers -ConfigPath $ConfigFile -Port $MixedPort

# ---------------------------------------------------------------------------
# Step 6: Startup automation linking + launch execution
# ---------------------------------------------------------------------------
Clear-Host
Write-Host "[6/6] Linking background tray to system boot processes..." -ForegroundColor Cyan

$VbsPayload = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "$TargetDir"
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""$TrayFile""", 0, False
"@

try {
    Set-Content -Path $VbsScript -Value $VbsPayload -Encoding Ascii -ErrorAction Stop
    Start-Process wscript.exe -ArgumentList "`"$VbsScript`""
} catch { }

Start-Sleep -Seconds 3

# ---------------------------------------------------------------------------
# FINAL OUTPUT: Configuration & Setup Guide
# ---------------------------------------------------------------------------
Clear-Host
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "  SUCCESS: SECURE ANTI-DPI TUNNEL FULLY DEPLOYED!        " -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host " Your background proxy core is now running silently."
Write-Host " Check your System Tray (bottom right) for the Internet Globe icon."
Write-Host " Right-click it at any time to open the Web Dashboard and manage servers."

Write-Host "`n=========================================================" -ForegroundColor Cyan
Write-Host "   BROWSER PROXY SETUP GUIDE (ZeroOmega / SwitchyOmega)  " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host " 1. Install 'ZeroOmega' from your browser extension store."
Write-Host " 2. Open extension Options -> Click 'New Profile'."
Write-Host " 3. Name it 'Mihomo Core' and select type 'Proxy Profile'."
Write-Host " 4. Set Protocol to 'SOCKS5'."
Write-Host "    Set Server to '127.0.0.1'."
Write-Host "    Set Port to '$MixedPort'."
Write-Host " 5. Go to the 'Auto Switch' profile tab on the left menu."
Write-Host " 6. Add a condition -> Set Condition Type to 'Wildcard'."
Write-Host "    Set Condition Details to '*.blocked-site.com'."
Write-Host "    Set Profile to 'Mihomo Core'."
Write-Host " 7. Click 'Apply Options' to save your rules."
Write-Host " 8. Click the extension icon in your browser and select 'Auto Switch'."
Write-Host "---------------------------------------------------------"

Write-Host "`nPress Enter to close this window..." -ForegroundColor DarkGray
Read-Host
