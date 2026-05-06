# ════════════════════════════════════════════════════════════════════════════
#  AI ARSENAL  ·  PUBLIC EDITION  v4.0
#  Author : Somanjan
#  GitHub : https://github.com/SomanjanPramanik/AI-Arsenal  
# ════════════════════════════════════════════════════════════════════════════
#
#  INSTALL (one time, 60 seconds):
#    1.  Open PowerShell as normal user (NOT admin)
#    2.  Run: notepad $PROFILE
#    3.  Paste this entire file → Save → Close
#    4.  Restart PowerShell
#    5.  Type: ai-setup    ← walks you through everything
#    6.  Type: ai-help     ← full command reference
#    7.  Type: ai-self-test ← verify everything works
#
#  SUPPORTED AI BACKENDS (choose ONE):
#    • Local  — Ollama  (free · private · works offline)
#    • Cloud  — Anthropic Claude API  (best quality · ~$0.01/query)
#    • Cloud  — OpenAI GPT-4o API     (popular · ~$0.01/query)
#
#  LOCAL SETUP (only if you choose Local):
#    1. Download → https://ollama.com  →  Install it
#    2. Open a terminal and pull a model:
#         ollama pull mistral        ← best for code  (needs ~4 GB RAM)
#         ollama pull gemma2:2b      ← fastest/lightest (needs ~2 GB RAM)
#         ollama pull moondream      ← adds image analysis
#    3. Optional Python tools (for PDF/Word/OCR features):
#         pip install PyMuPDF python-docx easyocr pillow requests
#
#  CLOUD SETUP (recommended — no GPU/local install needed):
#    1. Run: ai-setup → choose Cloud
#    2. Enter your API key:
#         Anthropic → https://console.anthropic.com  (starts with sk-ant-)
#         OpenAI    → https://platform.openai.com    (starts with sk-)
#
#  REQUIREMENTS:
#    • Windows 10/11  •  PowerShell 5.1 or 7+
#    • Internet connection (for Cloud mode or ai-weather / ai-web)
#    • Git (optional, for ai-diff / ai-commit / ai-git-push / ai-standup)
#    • Python 3.8+ (optional, for ai-ocr / ai-img PDF / ai-sum PDF)
#
# ════════════════════════════════════════════════════════════════════════════

Set-StrictMode -Off   # keep permissive — profile runs in user context

# ── GLOBAL CONSTANTS (never changed at runtime) ───────────────────────────
$Global:SC_VERSION     = "4.0"
$Global:SC_CONFIG_FILE = Join-Path $env:TEMP "sc_config.json"
$Global:SC_MAX_CHARS   = 12000
$Global:SC_MODEL       = "mistral:latest"   # overwritten by _SC-LoadConfig

# ════════════════════════════════════════════════════════════════════════════
#  CONFIG — LOAD / SAVE
# ════════════════════════════════════════════════════════════════════════════

function _SC-DefaultConfig {
    return [ordered]@{
        UserName    = ""
        AIMode      = "local"        # "local" | "cloud"
        APIKey      = ""
        APIProvider = ""             # "anthropic" | "openai"
        LocalModel  = "mistral:latest"
        MaxChars    = 12000
        City        = ""
        AnimStyle   = "instant"      # "glitch" | "typewriter" | "instant"
        Role        = ""
        SetupDone   = $false
    }
}

function _SC-LoadConfig {
    $cfg = _SC-DefaultConfig
    if (Test-Path $Global:SC_CONFIG_FILE) {
        try {
            $raw = Get-Content $Global:SC_CONFIG_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
            # Only copy known, expected keys — never blindly trust file content
            foreach ($key in $cfg.Keys) {
                if ($null -ne $raw.$key -and $raw.$key -ne "") {
                    $cfg[$key] = $raw.$key
                }
            }
        } catch {
            # Silently fall back to defaults — corrupt config is not fatal
        }
    }
    # Integrity check: if setup claimed done but name is blank, redo setup
    if ($cfg.SetupDone -and [string]::IsNullOrWhiteSpace($cfg.UserName)) {
        $cfg.SetupDone = $false
        _SC-SaveConfig $cfg | Out-Null
    }
    # Sync the one global that inner functions occasionally read directly
    $Global:SC_MODEL = $cfg.LocalModel
    return $cfg
}

function _SC-SaveConfig {
    param([hashtable]$Config)
    try {
        # Sanitize string values: strip control chars and double-quotes to keep JSON clean
        $safe = [ordered]@{}
        foreach ($k in $Config.Keys) {
            $v = $Config[$k]
            if ($v -is [string]) {
                $v = $v -replace '[\x00-\x1F"\\]', ''   # strip control + JSON-breaking chars
            }
            $safe[$k] = $v
        }
        $safe | ConvertTo-Json -Depth 3 | Set-Content $Global:SC_CONFIG_FILE -Encoding UTF8 -Force
        return $true
    } catch {
        Write-Host "  [!] Could not save config: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "      Your settings will work this session but won't persist." -ForegroundColor DarkGray
        Write-Host "      Fix: make sure $env:TEMP is writable." -ForegroundColor DarkCyan
        return $false
    }
}

# ════════════════════════════════════════════════════════════════════════════
#  APP / URL REGISTRY
# ════════════════════════════════════════════════════════════════════════════

$Global:SC_APPS = @{
    "brave"      = @("$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe",
                     "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe")
    "chrome"     = @("$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
                     "C:\Program Files\Google\Chrome\Application\chrome.exe")
    "firefox"    = @("C:\Program Files\Mozilla Firefox\firefox.exe",
                     "C:\Program Files (x86)\Mozilla Firefox\firefox.exe")
    "whatsapp"   = @("$env:LOCALAPPDATA\WhatsApp\WhatsApp.exe",
                     "$env:APPDATA\WhatsApp\WhatsApp.exe")
    "spotify"    = @("$env:APPDATA\Spotify\Spotify.exe",
                     "$env:LOCALAPPDATA\Microsoft\WindowsApps\Spotify.exe")
    "vscode"     = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
                     "C:\Program Files\Microsoft VS Code\Code.exe")
    "intellij"   = @("C:\Program Files\JetBrains\IntelliJ IDEA Community Edition*\bin\idea64.exe",
                     "C:\Program Files\JetBrains\IntelliJ IDEA*\bin\idea64.exe")
    "notepad"    = @("C:\Windows\System32\notepad.exe")
    "postman"    = @("$env:LOCALAPPDATA\Postman\Postman.exe",
                     "$env:APPDATA\Postman\Postman.exe")
    "discord"    = @("$env:LOCALAPPDATA\Discord\app-*\Discord.exe",
                     "$env:APPDATA\Discord\Discord.exe")
    "terminal"   = @("wt")
    "explorer"   = @("explorer.exe")
    "calculator" = @("calc.exe")
    "taskmgr"    = @("taskmgr.exe")
}

$Global:SC_URLS = @{
    "youtube"       = "https://youtube.com"
    "gmail"         = "https://mail.google.com"
    "github"        = "https://github.com"
    "linkedin"      = "https://linkedin.com"
    "stackoverflow" = "https://stackoverflow.com"
    "leetcode"      = "https://leetcode.com"
    "google"        = "https://google.com"
    "chatgpt"       = "https://chat.openai.com"
    "maven"         = "https://mvnrepository.com"
    "selenium"      = "https://selenium.dev/documentation"
}

# ════════════════════════════════════════════════════════════════════════════
#  FIRST-RUN SETUP
# ════════════════════════════════════════════════════════════════════════════

function ai-setup {
    <#
    .SYNOPSIS
    Interactive setup wizard. Run anytime to reconfigure everything.
    .DESCRIPTION
    Walks you through: name, role, AI backend (Local/Cloud), city, and animation style.
    All settings are saved locally — nothing is sent anywhere except your AI queries.
    .EXAMPLE
    ai-setup
    #>

    $cfg = _SC-LoadConfig
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       AI ARSENAL  v$($Global:SC_VERSION)  —  SETUP WIZARD        ║" -ForegroundColor Cyan
    Write-Host "  ║  All settings are stored locally on this PC.    ║" -ForegroundColor DarkGray
    Write-Host "  ║  Run  ai-setup  again anytime to reconfigure.   ║" -ForegroundColor DarkGray
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # ── [1/5] NAME ───────────────────────────────────────────────────────
    Write-Host "  [1/5] Your name  (shown in the welcome banner):" -ForegroundColor Yellow
    Write-Host "        Current: $(if($cfg.UserName){"'$($cfg.UserName)'"} else {'(not set)'})" -ForegroundColor DarkGray
    Write-Host "        Press Enter to keep current." -ForegroundColor DarkGray
    Write-Host "  › " -NoNewline -ForegroundColor White
    $name = (Read-Host).Trim()
    if (-not [string]::IsNullOrWhiteSpace($name)) { $cfg.UserName = $name }
    if ([string]::IsNullOrWhiteSpace($cfg.UserName)) { $cfg.UserName = "User" }

    # ── [2/5] ROLE ───────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  [2/5] Your role / tech stack:" -ForegroundColor Yellow
    Write-Host "        This personalises every AI response to your context." -ForegroundColor DarkGray
    Write-Host "        Examples:  Java SDET  |  Python Developer  |  DevOps Engineer" -ForegroundColor DarkGray
    Write-Host "        Current: $(if($cfg.Role){"'$($cfg.Role)'"} else {'(not set)'})" -ForegroundColor DarkGray
    Write-Host "  › " -NoNewline -ForegroundColor White
    $role = (Read-Host).Trim()
    if (-not [string]::IsNullOrWhiteSpace($role)) { $cfg.Role = $role }
    if ([string]::IsNullOrWhiteSpace($cfg.Role))  { $cfg.Role = "software developer" }

    # ── [3/5] AI BACKEND ─────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  [3/5] Choose your AI backend:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "        [1] Local  — Ollama  (free · private · offline-capable)" -ForegroundColor Gray
    Write-Host "             Needs: ollama.com installed + at least one model pulled" -ForegroundColor DarkGray
    Write-Host "             RAM:   mistral needs ~4 GB  |  gemma2:2b needs ~2 GB" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "        [2] Claude — Anthropic API  (highest quality · ~`$0.01/query)" -ForegroundColor Gray
    Write-Host "             Key at: https://console.anthropic.com" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "        [3] OpenAI — GPT-4o  (popular · ~`$0.01/query)" -ForegroundColor Gray
    Write-Host "             Key at: https://platform.openai.com" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "        Current: $($cfg.AIMode)$(if($cfg.APIProvider){" · $($cfg.APIProvider)"})" -ForegroundColor DarkCyan
    Write-Host "        Press Enter to keep current." -ForegroundColor DarkGray
    Write-Host "  › " -NoNewline -ForegroundColor White
    $choice = (Read-Host).Trim()

    switch ($choice) {
        "1" {
            $cfg.AIMode      = "local"
            $cfg.APIProvider = ""
            $cfg.APIKey      = ""
            Write-Host "  [✓] Local Ollama selected." -ForegroundColor Green
            Write-Host "      Checking if Ollama is running..." -ForegroundColor DarkGray
            try {
                $tags   = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 4 -EA Stop
                $models = @($tags.models | ForEach-Object { $_.name })
                if ($models.Count -gt 0) {
                    Write-Host "  [✓] Ollama is online. Models found: $($models -join ', ')" -ForegroundColor Green
                    $cfg.LocalModel  = $models[0]
                    $Global:SC_MODEL = $models[0]
                } else {
                    Write-Host "  [!] Ollama is running but no models are installed yet." -ForegroundColor Yellow
                    Write-Host "      Open a new terminal and run ONE of these:" -ForegroundColor DarkGray
                    Write-Host "        ollama pull mistral     ← best for code  (~4 GB RAM needed)" -ForegroundColor Cyan
                    Write-Host "        ollama pull gemma2:2b   ← lightest option (~2 GB RAM needed)" -ForegroundColor Cyan
                    Write-Host "      Then run  ai-setup  again to register the model." -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "  [!] Ollama is not running (or not installed)." -ForegroundColor Yellow
                Write-Host "      To fix this:" -ForegroundColor DarkGray
                Write-Host "        1. Download and install Ollama → https://ollama.com" -ForegroundColor Cyan
                Write-Host "        2. Open a new terminal → run: ollama pull mistral" -ForegroundColor Cyan
                Write-Host "        3. Then come back and run: ai-setup" -ForegroundColor Cyan
                Write-Host "      Your settings have been saved. Fix Ollama, then reopen PowerShell." -ForegroundColor DarkGray
            }
        }
        "2" {
            $cfg.AIMode      = "cloud"
            $cfg.APIProvider = "anthropic"
            Write-Host "  Enter your Anthropic API key (starts with  sk-ant-...):" -ForegroundColor Yellow
            Write-Host "  Find it at: https://console.anthropic.com" -ForegroundColor DarkGray
            Write-Host "  › " -NoNewline -ForegroundColor White
            $key = (Read-Host).Trim()
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                if ($key -notmatch '^sk-ant-') {
                    Write-Host "  [!] That doesn't look like an Anthropic key (should start with sk-ant-)." -ForegroundColor Yellow
                    Write-Host "      Saved anyway — if AI calls fail, run ai-setup and re-enter it." -ForegroundColor DarkGray
                }
                $cfg.APIKey = $key
                Write-Host "  [✓] Anthropic API key saved." -ForegroundColor Green
            } else {
                Write-Host "  [!] No key entered. Run  ai-setup  again to add it." -ForegroundColor Yellow
                Write-Host "      Without a key, cloud AI commands will not work." -ForegroundColor DarkGray
            }
        }
        "3" {
            $cfg.AIMode      = "cloud"
            $cfg.APIProvider = "openai"
            Write-Host "  Enter your OpenAI API key (starts with  sk-...):" -ForegroundColor Yellow
            Write-Host "  Find it at: https://platform.openai.com" -ForegroundColor DarkGray
            Write-Host "  › " -NoNewline -ForegroundColor White
            $key = (Read-Host).Trim()
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                if ($key -notmatch '^sk-') {
                    Write-Host "  [!] That doesn't look like an OpenAI key (should start with sk-)." -ForegroundColor Yellow
                    Write-Host "      Saved anyway — if AI calls fail, run ai-setup and re-enter it." -ForegroundColor DarkGray
                }
                $cfg.APIKey = $key
                Write-Host "  [✓] OpenAI API key saved." -ForegroundColor Green
            } else {
                Write-Host "  [!] No key entered. Run  ai-setup  again to add it." -ForegroundColor Yellow
                Write-Host "      Without a key, cloud AI commands will not work." -ForegroundColor DarkGray
            }
        }
        "" { Write-Host "  [~] Backend unchanged: $($cfg.AIMode)" -ForegroundColor DarkGray }
        default {
            Write-Host "  [!] '$choice' is not a valid option (1, 2, or 3)." -ForegroundColor Yellow
            Write-Host "      Backend unchanged: $($cfg.AIMode)" -ForegroundColor DarkGray
        }
    }

    # ── [4/5] CITY ───────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  [4/5] Your city for  ai-weather:" -ForegroundColor Yellow
    Write-Host "        Use the English name exactly as it appears on Google Maps." -ForegroundColor DarkGray
    Write-Host "        Current: $(if($cfg.City){"'$($cfg.City)'"} else {'(not set — ai-weather will not work)'})" -ForegroundColor DarkGray
    Write-Host "  › " -NoNewline -ForegroundColor White
    $city = (Read-Host).Trim()
    if (-not [string]::IsNullOrWhiteSpace($city)) { $cfg.City = $city }

    # ── [5/5] ANIMATION ──────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  [5/5] Welcome banner animation:" -ForegroundColor Yellow
    Write-Host "        [1] Glitch      — Matrix-style scramble  (~5 s, looks cool)" -ForegroundColor Gray
    Write-Host "        [2] Typewriter  — Letters appear one by one  (~3 s)" -ForegroundColor Gray
    Write-Host "        [3] Instant     — No animation  (fastest, recommended)" -ForegroundColor Gray
    Write-Host "        Current: $($cfg.AnimStyle)" -ForegroundColor DarkGray
    Write-Host "        Press Enter to keep current." -ForegroundColor DarkGray
    Write-Host "  › " -NoNewline -ForegroundColor White
    $anim = (Read-Host).Trim()
    switch ($anim) {
        "1" { $cfg.AnimStyle = "glitch";     Write-Host "  [✓] Glitch animation." -ForegroundColor Green }
        "2" { $cfg.AnimStyle = "typewriter"; Write-Host "  [✓] Typewriter animation." -ForegroundColor Green }
        "3" { $cfg.AnimStyle = "instant";    Write-Host "  [✓] Instant (no animation)." -ForegroundColor Green }
        ""  { Write-Host "  [~] Animation unchanged: $($cfg.AnimStyle)" -ForegroundColor DarkGray }
        default {
            Write-Host "  [!] '$anim' is not valid (1, 2, or 3). Animation unchanged." -ForegroundColor Yellow
        }
    }

    $cfg.SetupDone = $true
    _SC-SaveConfig $cfg | Out-Null
    $Global:SC_MODEL = $cfg.LocalModel

    Write-Host ""
    Write-Host "  ══════════════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "  [✓] Setup complete!  Welcome, $($cfg.UserName)." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor DarkGray
    Write-Host "    ai-self-test  ← verify everything is working" -ForegroundColor Cyan
    Write-Host "    ai-help       ← see every command" -ForegroundColor Cyan
    if ($cfg.AIMode -eq "local") {
        Write-Host "    ai-run        ← start Ollama and load your model" -ForegroundColor Cyan
    }
    Write-Host ""
}

# Auto-run setup on very first use
$_firstRunCfg = _SC-LoadConfig
if (-not $_firstRunCfg.SetupDone) {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   AI ARSENAL — First run detected on this PC.   ║" -ForegroundColor Cyan
    Write-Host "  ║   Let's set everything up in under 60 seconds.  ║" -ForegroundColor DarkGray
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    ai-setup
}
Remove-Variable _firstRunCfg -EA SilentlyContinue

# ════════════════════════════════════════════════════════════════════════════
#  SYSTEM HEALTH UTILITIES  (internal — called by other functions)
# ════════════════════════════════════════════════════════════════════════════

function _SC-GetFreeRAM_GB {
    try { return [math]::Round((Get-CimInstance Win32_OperatingSystem -EA Stop).FreePhysicalMemory / 1MB, 1) }
    catch { return 999 }   # if WMI fails, assume plenty of RAM — don't block the user
}

function _SC-WarnLowRAM {
    $free = _SC-GetFreeRAM_GB
    if ($free -eq 999) { return }   # WMI unavailable — skip silently
    if ($free -lt 2.0) {
        Write-Host ""
        Write-Host "  ⚠️  WARNING: Only ${free} GB RAM free." -ForegroundColor Red
        Write-Host "      AI may crash or be very slow right now." -ForegroundColor Red
        Write-Host "      What you can do:" -ForegroundColor Yellow
        Write-Host "        • Close Chrome tabs, VS Code, Spotify, or other heavy apps." -ForegroundColor Yellow
        Write-Host "        • Run  ai-stop  to flush VRAM, then retry." -ForegroundColor Yellow
        Write-Host "        • Switch to Cloud AI (no RAM needed):  ai-setup" -ForegroundColor Cyan
        Write-Host ""
    } elseif ($free -lt 3.5) {
        Write-Host "  [~] RAM: ${free} GB free — tight. AI may be slow." -ForegroundColor Yellow
        Write-Host "      Tip: close heavy apps first, or run  ai-stop  to free memory." -ForegroundColor DarkGray
    }
}

function _SC-AutoFlushIfNeeded {
    # Proactively kill the inference process if RAM is critically low
    $free  = _SC-GetFreeRAM_GB
    $infer = Get-Process "ollama_llama_server", "llama-server" -EA SilentlyContinue
    if ($free -ne 999 -and $free -lt 1.5 -and $infer) {
        Write-Host "  [!] Critical RAM pressure (${free} GB free). Auto-flushing VRAM..." -ForegroundColor Red
        _SC-FlushVRAM
        Start-Sleep -Seconds 1
    }
}

function _SC-FlushVRAM {
    $infer = Get-Process "ollama_llama_server", "llama-server" -EA SilentlyContinue
    if ($infer) {
        $infer | Stop-Process -Force -EA SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "  [✓] VRAM flushed. Model will reload on your next request." -ForegroundColor DarkGray
    }
}

function _SC-OllamaReachable {
    # Returns $true if Ollama HTTP API responds. Prints nothing — callers decide messaging.
    try {
        $null = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 4 -EA Stop
        return $true
    } catch { return $false }
}

function _SC-OllamaCheck {
    # Returns $true or prints a clear fix guide and returns $false
    if (_SC-OllamaReachable) { return $true }
    Write-Host ""
    Write-Host "  [✗] Ollama is not running." -ForegroundColor Red
    Write-Host "  ── How to fix ───────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   Option A — Start it now:" -ForegroundColor Yellow
    Write-Host "     1. Open a new PowerShell window" -ForegroundColor Gray
    Write-Host "     2. Type: ollama serve" -ForegroundColor Cyan
    Write-Host "     3. Come back here and retry your command" -ForegroundColor Gray
    Write-Host "   Option B — Let the profile start it:" -ForegroundColor Yellow
    Write-Host "     Run: ai-run  (starts Ollama + lets you pick a model)" -ForegroundColor Cyan
    Write-Host "   Option C — Switch to Cloud AI (no local install needed):" -ForegroundColor Yellow
    Write-Host "     Run: ai-setup  →  choose option 2 or 3" -ForegroundColor Cyan
    Write-Host ""
    return $false
}

function _SC-OllamaListModels {
    try {
        $tags = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 5 -EA Stop
        return @($tags.models | ForEach-Object { $_.name })
    } catch { return @() }
}

# ════════════════════════════════════════════════════════════════════════════
#  USAGE TRACKER  (lightweight — one JSON file, batched writes)
# ════════════════════════════════════════════════════════════════════════════

function _SC-Track {
    param([string]$Cmd)
    # Non-blocking — any failure here must never interrupt the user
    try {
        $f    = Join-Path $env:TEMP "sc_usage.json"
        $data = @{}
        if (Test-Path $f) {
            $raw = Get-Content $f -Raw -Encoding UTF8 -EA SilentlyContinue
            if ($raw) {
                (ConvertFrom-Json $raw).PSObject.Properties |
                    ForEach-Object { $data[$_.Name] = [int]$_.Value }
            }
        }
        $data[$Cmd] = if ($data.ContainsKey($Cmd)) { $data[$Cmd] + 1 } else { 1 }
        $data | ConvertTo-Json -Compress | Set-Content $f -Encoding UTF8 -Force
    } catch { }
}

# ════════════════════════════════════════════════════════════════════════════
#  CORE AI ENGINE — LOCAL + CLOUD + CASCADING FALLBACK
# ════════════════════════════════════════════════════════════════════════════

function _SC-SystemPrompt {
    $cfg  = _SC-LoadConfig
    $role = if (-not [string]::IsNullOrWhiteSpace($cfg.Role)) { $cfg.Role } else { "software developer" }
    return "You are a senior expert assistant for a $role. Be concise, technical, and accurate. Never wrap code in markdown fences unless explicitly asked."
}

function _SC-CallCloud {
    <#
    Calls Anthropic or OpenAI. Returns response string or "" on failure.
    Caller decides whether to print.
    #>
    param(
        [string]$Prompt,
        [string]$System  = "",
        [int]   $MaxTok  = 2000
    )
    if ([string]::IsNullOrWhiteSpace($System)) { $System = _SC-SystemPrompt }
    $cfg = _SC-LoadConfig

    if ([string]::IsNullOrWhiteSpace($cfg.APIKey)) {
        Write-Host ""
        Write-Host "  [✗] No API key is configured." -ForegroundColor Red
        Write-Host "  ── Fix ──────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "   Run: ai-setup  →  choose your cloud provider (2 or 3)" -ForegroundColor Cyan
        Write-Host "   Then enter your API key when prompted." -ForegroundColor Gray
        Write-Host ""
        return ""
    }

    if ($cfg.APIProvider -eq "anthropic") {
        $body = @{
            model      = "claude-3-5-sonnet-20241022"
            max_tokens = $MaxTok
            system     = $System
            messages   = @(@{ role = "user"; content = $Prompt })
        } | ConvertTo-Json -Depth 10 -Compress
        try {
            $r = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" -Method POST `
                -Headers @{
                    "x-api-key"         = $cfg.APIKey
                    "anthropic-version" = "2023-06-01"
                    "content-type"      = "application/json"
                } -Body $body -TimeoutSec 90 -EA Stop
            return $r.content[0].text
        } catch {
            $e = $_.Exception.Message
            Write-Host ""
            Write-Host "  [✗] Anthropic API error." -ForegroundColor Red
            if ($e -match "401|invalid_api_key|authentication") {
                Write-Host "      Your API key is wrong or expired." -ForegroundColor Yellow
                Write-Host "      Fix: ai-setup  →  re-enter your Anthropic key." -ForegroundColor Cyan
            } elseif ($e -match "429|rate_limit|quota") {
                Write-Host "      You've hit your rate limit or billing quota." -ForegroundColor Yellow
                Write-Host "      Fix: wait 60 s, or check console.anthropic.com for billing." -ForegroundColor Cyan
            } elseif ($e -match "timeout|Timeout") {
                Write-Host "      Request timed out (> 90 s)." -ForegroundColor Yellow
                Write-Host "      Fix: check your internet connection and retry." -ForegroundColor Cyan
            } else {
                Write-Host "      Detail: $e" -ForegroundColor DarkGray
            }
            Write-Host ""
            return ""
        }
    }

    if ($cfg.APIProvider -eq "openai") {
        $body = @{
            model    = "gpt-4o"
            messages = @(
                @{ role = "system"; content = $System }
                @{ role = "user";   content = $Prompt }
            )
        } | ConvertTo-Json -Depth 10 -Compress
        try {
            $r = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" -Method POST `
                -Headers @{
                    "Authorization" = "Bearer $($cfg.APIKey)"
                    "Content-Type"  = "application/json"
                } -Body $body -TimeoutSec 90 -EA Stop
            return $r.choices[0].message.content
        } catch {
            $e = $_.Exception.Message
            Write-Host ""
            Write-Host "  [✗] OpenAI API error." -ForegroundColor Red
            if ($e -match "401|invalid_api_key") {
                Write-Host "      Your API key is wrong or expired." -ForegroundColor Yellow
                Write-Host "      Fix: ai-setup  →  re-enter your OpenAI key." -ForegroundColor Cyan
            } elseif ($e -match "429|quota") {
                Write-Host "      Rate limit or quota exceeded." -ForegroundColor Yellow
                Write-Host "      Fix: wait a moment or check platform.openai.com for billing." -ForegroundColor Cyan
            } else {
                Write-Host "      Detail: $e" -ForegroundColor DarkGray
            }
            Write-Host ""
            return ""
        }
    }

    Write-Host "  [✗] No cloud provider is configured." -ForegroundColor Red
    Write-Host "      Fix: ai-setup  →  choose option 2 (Claude) or 3 (OpenAI)." -ForegroundColor Cyan
    return ""
}

function _SC-CallOllama {
    <#
    Calls a local Ollama model. Returns response string or "" on failure.
    On 500 / timeout: flushes VRAM and returns "" — caller handles retry.
    #>
    param(
        [string]$Prompt,
        [string]$Model  = $Global:SC_MODEL,
        [string]$System = "",
        [float] $Temp   = 0.4
    )
    if ([string]::IsNullOrWhiteSpace($System)) { $System = _SC-SystemPrompt }

    $body = @{
        model   = $Model
        system  = $System
        prompt  = $Prompt
        stream  = $false
        options = @{ temperature = $Temp }
    } | ConvertTo-Json -Compress -Depth 5

    try {
        $r = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
            -Method POST -Body $body -ContentType "application/json" -TimeoutSec 180 -EA Stop
        return $r.response
    } catch {
        $e = $_.Exception.Message
        if ($e -match "500|timeout|Timeout|connection|refused") {
            Write-Host "  [~] Model '$Model' crashed or timed out. Flushing VRAM..." -ForegroundColor Yellow
            _SC-FlushVRAM
        } else {
            Write-Host "  [✗] Ollama error: $e" -ForegroundColor Red
        }
        return ""
    }
}

function _SC-Ask {
    <#
    Main AI dispatcher.
    • Cloud mode  → calls cloud directly (no cascade needed).
    • Local mode  → 3-stage cascade:
        Stage 1: primary model (full prompt, 2 attempts)
        Stage 2: best available fast model (simplified prompt if provided)
        Stage 3: fatal — clear recovery instructions
    Returns response string. Prints result to console unless -Silent.
    #>
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [string]$FallbackPrompt = "",
        [string]$System         = "",
        [float] $Temp           = 0.4,
        [switch]$Silent
    )
    if ([string]::IsNullOrWhiteSpace($System)) { $System = _SC-SystemPrompt }
    $cfg = _SC-LoadConfig

    # ── CLOUD PATH ────────────────────────────────────────────────────────
    if ($cfg.AIMode -eq "cloud") {
        $p    = if ($FallbackPrompt -ne "") { $FallbackPrompt } else { $Prompt }
        $resp = _SC-CallCloud -Prompt $p -System $System
        if (-not [string]::IsNullOrWhiteSpace($resp) -and -not $Silent) {
            Write-Host ""; Write-Host $resp -ForegroundColor Green; Write-Host ""
        }
        return $resp
    }

    # ── LOCAL PATH — guard checks ─────────────────────────────────────────
    if (-not (_SC-OllamaCheck)) { return "" }
    _SC-WarnLowRAM
    _SC-AutoFlushIfNeeded

    $available = _SC-OllamaListModels
    if ($available.Count -eq 0) {
        Write-Host ""
        Write-Host "  [✗] No models are installed in Ollama." -ForegroundColor Red
        Write-Host "  ── Fix ──────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "   Open a new terminal and run one of these:" -ForegroundColor Yellow
        Write-Host "     ollama pull mistral     ← best for code  (~4 GB RAM)" -ForegroundColor Cyan
        Write-Host "     ollama pull gemma2:2b   ← lightest option (~2 GB RAM)" -ForegroundColor Cyan
        Write-Host "   Then retry your command." -ForegroundColor Gray
        Write-Host ""
        return ""
    }

    $primaryModel = $Global:SC_MODEL

    # Pick the best available fast fallback (ordered by preference)
    $fastCandidates = @("gemma2:2b","gemma:2b","phi3:mini","tinyllama","qwen2:0.5b")
    $safeModel = $fastCandidates | Where-Object { $available -contains $_ } | Select-Object -First 1
    if (-not $safeModel) {
        # Any model other than primary works as last-resort fallback
        $safeModel = $available | Where-Object { $_ -ne $primaryModel } | Select-Object -First 1
    }

    # ── STAGE 1: Primary model (2 attempts) ───────────────────────────────
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        $resp = _SC-CallOllama -Prompt $Prompt -Model $primaryModel -System $System -Temp $Temp
        if (-not [string]::IsNullOrWhiteSpace($resp)) {
            if (-not $Silent) { Write-Host ""; Write-Host $resp -ForegroundColor Green; Write-Host "" }
            return $resp
        }
        if ($attempt -eq 1) {
            Write-Host "  [~] Retrying with $primaryModel (attempt 2/2)..." -ForegroundColor DarkGray
            Start-Sleep -Seconds 2
        }
    }

    # ── STAGE 2: Fast fallback model ──────────────────────────────────────
    if ($safeModel -and $safeModel -ne $primaryModel) {
        $p2 = if ($FallbackPrompt -ne "") { $FallbackPrompt } else { $Prompt }
        Write-Host "  [!] '$primaryModel' failed. Trying fallback '$safeModel'..." -ForegroundColor Yellow
        $resp = _SC-CallOllama -Prompt $p2 -Model $safeModel -System $System -Temp $Temp
        if (-not [string]::IsNullOrWhiteSpace($resp)) {
            Write-Host "  [~] Response from fallback model '$safeModel':" -ForegroundColor DarkYellow
            if (-not $Silent) { Write-Host ""; Write-Host $resp -ForegroundColor Green; Write-Host "" }
            return $resp
        }
    }

    # ── STAGE 3: All models failed ────────────────────────────────────────
    Write-Host ""
    Write-Host "  [✗] ALL MODELS FAILED — could not get a response." -ForegroundColor White -BackgroundColor DarkRed
    Write-Host "  ── Recovery steps ───────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "   1. Run  ai-stop  → choose [Y] to free all memory" -ForegroundColor Yellow
    Write-Host "   2. Close Chrome tabs, VS Code, Spotify — anything heavy" -ForegroundColor Yellow
    Write-Host "   3. Run  ai-run   → pick a lighter model (gemma2:2b uses only 2 GB)" -ForegroundColor Yellow
    Write-Host "   4. Retry your command" -ForegroundColor Yellow
    Write-Host "   OR: Switch to Cloud AI (no local GPU/RAM needed):" -ForegroundColor Cyan
    Write-Host "         ai-setup  →  choose option 2 or 3" -ForegroundColor Cyan
    Write-Host ""
    return ""
}

# ── HELPER UTILITIES ──────────────────────────────────────────────────────

function _SC-Trim {
    param([string]$s, [int]$max = $Global:SC_MAX_CHARS)
    if ($s.Length -gt $max) {
        return $s.Substring(0, $max) + "`n...[content truncated to $max chars]"
    }
    return $s
}

function _SC-StripFences {
    param([string]$text)
    return ($text -replace '```[\w]*\r?\n?', '' -replace '\r?\n?```', '').Trim()
}

function _SC-ReadFile {
    <#
    Reads plain text, PDF (via PyMuPDF), or Word doc (via python-docx).
    Returns file content as string, or "" with a clear error message.
    #>
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host ""
        Write-Host "  [✗] File not found: $Path" -ForegroundColor Red
        Write-Host "      Check the path — use Tab to autocomplete filenames." -ForegroundColor DarkGray
        Write-Host "      Current directory: $(Get-Location)" -ForegroundColor DarkGray
        Write-Host ""
        return ""
    }
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()

    switch ($ext) {
        ".pdf" {
            $pyScript = @"
import sys, fitz
try:
    doc = fitz.open(sys.argv[1])
    print('\n'.join([p.get_text() for p in doc]))
except Exception as e:
    print(f"PDF_ERROR:{e}")
"@
            $tmp = Join-Path $env:TEMP "sc_read_pdf.py"
            $pyScript | Set-Content $tmp -Encoding UTF8
            $out = (python $tmp $Path 2>&1) -join "`n"
            if ($out -match "ModuleNotFoundError|No module named 'fitz'") {
                Write-Host ""
                Write-Host "  [✗] PyMuPDF is not installed — needed to read PDF files." -ForegroundColor Red
                Write-Host "      Fix: open a terminal and run:" -ForegroundColor Yellow
                Write-Host "        pip install PyMuPDF" -ForegroundColor Cyan
                Write-Host "      Then retry: ai-sum `"$Path`"" -ForegroundColor DarkGray
                Write-Host ""
                return ""
            }
            if ($out -match "^PDF_ERROR:") {
                Write-Host "  [✗] Could not read PDF: $($out -replace '^PDF_ERROR:','')" -ForegroundColor Red
                Write-Host "      The file may be encrypted, corrupted, or scanned (image-only)." -ForegroundColor DarkGray
                Write-Host "      Try: ai-ocr `"$Path`"  to extract text from a scanned PDF." -ForegroundColor Cyan
                return ""
            }
            return $out
        }
        ".docx" {
            $pyScript = @"
import sys
from docx import Document
try:
    doc = Document(sys.argv[1])
    print('\n'.join([p.text for p in doc.paragraphs]))
except Exception as e:
    print(f"DOCX_ERROR:{e}")
"@
            $tmp = Join-Path $env:TEMP "sc_read_docx.py"
            $pyScript | Set-Content $tmp -Encoding UTF8
            $out = (python $tmp $Path 2>&1) -join "`n"
            if ($out -match "ModuleNotFoundError|No module named 'docx'") {
                Write-Host ""
                Write-Host "  [✗] python-docx is not installed — needed to read .docx files." -ForegroundColor Red
                Write-Host "      Fix: open a terminal and run:" -ForegroundColor Yellow
                Write-Host "        pip install python-docx" -ForegroundColor Cyan
                Write-Host "      Then retry your command." -ForegroundColor DarkGray
                Write-Host ""
                return ""
            }
            if ($out -match "^DOCX_ERROR:") {
                Write-Host "  [✗] Could not read .docx: $($out -replace '^DOCX_ERROR:','')" -ForegroundColor Red
                Write-Host "      The file may be corrupted or password-protected." -ForegroundColor DarkGray
                return ""
            }
            return $out
        }
        default {
            # Plain text / code files
            $supported = @(".txt",".java",".py",".ps1",".js",".ts",".cs",".xml",
                           ".json",".md",".html",".css",".yaml",".yml",".sh",".rb",".go",".rs")
            if ($ext -notin $supported) {
                Write-Host "  [!] '$ext' files are not officially supported." -ForegroundColor Yellow
                Write-Host "      Trying to read as plain text anyway..." -ForegroundColor DarkGray
                Write-Host "      Supported types: $($supported -join ', ')" -ForegroundColor DarkGray
            }
            $content = Get-Content $Path -Raw -Encoding UTF8 -EA SilentlyContinue
            if ($null -eq $content) {
                Write-Host "  [✗] Could not read '$Path'." -ForegroundColor Red
                Write-Host "      The file may be binary, empty, or locked by another process." -ForegroundColor DarkGray
                Write-Host "      For images: use  ai-img `"$Path`"  instead." -ForegroundColor Cyan
                return ""
            }
            return $content
        }
    }
}

# Easter egg: authorship attribution (decoded only when "who made you" is asked)
function _SC-ShowAuthor {
    $sig = [System.Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String("ICAgWyBPVkVSUklERSBdIEFJIEFyc2VuYWwgdjQuMCB3YXMgZm9yZ2VkIGJ5IFNvbWFuamFuLg=="))
    Write-Host "`n$sig`n" -ForegroundColor Magenta
}

# ════════════════════════════════════════════════════════════════════════════
#  BASIC AI & CHAT
# ════════════════════════════════════════════════════════════════════════════

function ai {
    <#
    .SYNOPSIS
    Ask the AI anything — fastest one-shot command.
    .EXAMPLE
    ai "what is dependency injection?"
    ai "write a regex that matches email addresses"
    ai "difference between HashMap and TreeMap in Java"
    #>
    param([Parameter(Mandatory)][string]$Question)
    _SC-Track "ai"
    if ($Question -match "who (made|created|built|developed|wrote) you") { _SC-ShowAuthor; return }
    $cfg = _SC-LoadConfig
    $tag = if ($cfg.AIMode -eq "cloud") { $cfg.APIProvider } else { $Global:SC_MODEL }
    Write-Host ""; Write-Host "  [ ai › $tag ]" -ForegroundColor DarkCyan
    _SC-Ask -Prompt $Question | Out-Null
}

function ai-ask {
    <#
    .SYNOPSIS
    Fast factual question. Handles time/date locally (no AI needed).
    .EXAMPLE
    ai-ask "what time is it?"
    ai-ask "what is the difference between == and .equals() in Java?"
    ai-ask "explain Big O notation"
    #>
    param([Parameter(Mandatory)][string]$Question)
    _SC-Track "ai-ask"
    if ($Question -match "who (made|created|built|developed|wrote) you") { _SC-ShowAuthor; return }
    $q = $Question.ToLower()
    if ($q -match '\b(time|clock)\b') {
        Write-Host ""; Write-Host "  🕒  $(Get-Date -Format 'HH:mm:ss')  ·  $(Get-Date -Format 'dddd, dd MMMM yyyy')" -ForegroundColor Cyan; Write-Host ""; return
    }
    if ($q -match '\b(date|today|day)\b') {
        Write-Host ""; Write-Host "  📅  $(Get-Date -Format 'dddd, dd MMMM yyyy')" -ForegroundColor Cyan
        Write-Host "  🗓  Week $(Get-Date -UFormat '%V') of $(Get-Date -Format 'yyyy')" -ForegroundColor DarkCyan; Write-Host ""; return
    }
    Write-Host ""; Write-Host "  [ ai-ask ] Thinking..." -ForegroundColor DarkCyan
    _SC-Ask -Prompt "Answer this clearly and concisely: $Question" -System "You are a helpful assistant. Be brief and direct." | Out-Null
}

function ai-chat {
    <#
    .SYNOPSIS
    Multi-turn conversation with full memory for the session.
    .DESCRIPTION
    Commands inside the chat:
      exit / quit   — end the session
      clear         — wipe conversation memory (start fresh)
      save          — export this session to a text file
      /file <path>  — inject a file's content into the conversation
    .EXAMPLE
    ai-chat
    #>
    _SC-Track "ai-chat"
    $cfg = _SC-LoadConfig
    if ($cfg.AIMode -eq "local" -and -not (_SC-OllamaCheck)) { return }
    _SC-WarnLowRAM

    $tag = if ($cfg.AIMode -eq "cloud") { $cfg.APIProvider } else { $Global:SC_MODEL }
    Write-Host ""; Write-Host "  [ AI CHAT · $tag ]" -ForegroundColor Cyan
    Write-Host "  Inside this chat you can type:" -ForegroundColor DarkGray
    Write-Host "    exit / quit    — end the session" -ForegroundColor DarkGray
    Write-Host "    clear          — wipe memory and start fresh" -ForegroundColor DarkGray
    Write-Host "    save           — export conversation to a file" -ForegroundColor DarkGray
    Write-Host "    /file <path>   — inject a file into the conversation" -ForegroundColor DarkGray
    Write-Host ""; Write-Host "  Start typing your message below:" -ForegroundColor DarkGray; Write-Host ""

    # Use a list of turn objects instead of raw string to avoid "Human:" injection bug
    $turns     = [System.Collections.Generic.List[hashtable]]::new()
    $sysprompt = "You are a helpful assistant with memory of this conversation. Be thorough but concise."

    while ($true) {
        Write-Host "  You › " -NoNewline -ForegroundColor Yellow
        $inp = Read-Host
        if ([string]::IsNullOrWhiteSpace($inp)) { continue }
        $lower = $inp.Trim().ToLower()

        if ($lower -in @("exit","quit","bye","q")) {
            # Auto-save if session has content
            if ($turns.Count -gt 0) {
                $f = Join-Path $env:TEMP "sc_chat_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
                ($turns | ForEach-Object { "$($_.role): $($_.content)" }) -join "`n`n" |
                    Set-Content $f -Encoding UTF8
                Write-Host "  [✓] Session auto-saved → $f" -ForegroundColor DarkGray
            }
            Write-Host "  [Session ended]" -ForegroundColor DarkGray; break
        }

        if ($lower -eq "clear") {
            $turns.Clear()
            Write-Host "  [✓] Memory cleared. Starting fresh." -ForegroundColor DarkGray; continue
        }

        if ($lower -eq "save") {
            if ($turns.Count -eq 0) { Write-Host "  [~] Nothing to save yet." -ForegroundColor DarkGray; continue }
            $f = Join-Path $env:TEMP "sc_chat_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            ($turns | ForEach-Object { "$($_.role): $($_.content)" }) -join "`n`n" |
                Set-Content $f -Encoding UTF8
            Write-Host "  [✓] Saved → $f" -ForegroundColor Green; continue
        }

        if ($lower -match "who (made|created|built|developed|wrote) you") { _SC-ShowAuthor; continue }

        if ($inp -match '^/file\s+(.+)') {
            $fPath = $Matches[1].Trim().Trim('"')
            $fc    = _SC-Trim (_SC-ReadFile $fPath)
            if ([string]::IsNullOrWhiteSpace($fc)) { continue }
            $turns.Add(@{ role = "user"; content = "[File: $([System.IO.Path]::GetFileName($fPath))]`n$fc" })
            Write-Host "  [✓] Injected: $([System.IO.Path]::GetFileName($fPath))  ($($fc.Length) chars)" -ForegroundColor Green
            continue
        }

        $turns.Add(@{ role = "user"; content = $inp })

        # Build prompt from turn history — trim oldest turns when too long
        $histStr = ($turns | ForEach-Object { "$($_.role.ToUpper()): $($_.content)" }) -join "`n`n"
        while ($histStr.Length -gt $Global:SC_MAX_CHARS -and $turns.Count -gt 2) {
            $turns.RemoveAt(0)   # drop oldest turn
            $histStr = ($turns | ForEach-Object { "$($_.role.ToUpper()): $($_.content)" }) -join "`n`n"
        }

        _SC-AutoFlushIfNeeded
        $resp = _SC-Ask -Prompt "$histStr`n`nASSISTANT:" -System $sysprompt -Silent
        if (-not [string]::IsNullOrWhiteSpace($resp)) {
            $turns.Add(@{ role = "assistant"; content = $resp })
            Write-Host ""; Write-Host "  AI  › " -NoNewline -ForegroundColor Green
            Write-Host $resp; Write-Host ""
        } else {
            Write-Host "  [!] The AI returned an empty response." -ForegroundColor Yellow
            Write-Host "      This can happen when the model crashes or the prompt is too long." -ForegroundColor DarkGray
            Write-Host "      Try: type  clear  to reset memory, then ask again." -ForegroundColor DarkGray
            Write-Host "           Or type  exit  and run  ai-stop  to free memory." -ForegroundColor DarkGray
        }
    }
}

function ai-cmd {
    <#
    .SYNOPSIS
    Describe a task in English — get a ready-to-run PowerShell command.
    .EXAMPLE
    ai-cmd "list all files modified in the last 24 hours"
    ai-cmd "find all Java files in this folder containing the word Exception"
    ai-cmd "delete all .log files older than 7 days"
    #>
    param([Parameter(Mandatory)][string]$Task)
    _SC-Track "ai-cmd"
    Write-Host ""; Write-Host "  [ ai-cmd ] Generating command for:" -ForegroundColor DarkCyan
    Write-Host "  $Task" -ForegroundColor White; Write-Host ""
    $raw = _SC-Ask -Prompt "You are a PowerShell expert. Task: $Task`nRespond with ONLY the raw PowerShell command(s). No markdown, no backticks, no explanation." `
                   -System "Return only raw PowerShell. No explanation. No markdown fences." -Silent
    $cmd = _SC-StripFences $raw
    if ([string]::IsNullOrWhiteSpace($cmd)) {
        Write-Host "  [!] Could not generate a command for that task." -ForegroundColor Yellow
        Write-Host "      Try rephrasing. Example:" -ForegroundColor DarkGray
        Write-Host "        ai-cmd `"show me all .txt files in the current folder`"" -ForegroundColor Cyan
        return
    }
    Write-Host "  Generated command:" -ForegroundColor Gray
    Write-Host ""; Write-Host "  $cmd" -ForegroundColor Green; Write-Host ""
    Write-Host "  [R] Run it   [C] Copy to clipboard   [S] Skip" -ForegroundColor Yellow
    $choice = (Read-Host "  Choice").Trim().ToUpper()
    switch ($choice) {
        "R" {
            Write-Host "  Running..." -ForegroundColor DarkGray
            try { Invoke-Expression $cmd }
            catch {
                Write-Host "  [✗] Command failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "      You can copy it with [C] and run it manually to see the full error." -ForegroundColor DarkGray
            }
        }
        "C" { Set-Clipboard -Value $cmd; Write-Host "  [✓] Copied to clipboard." -ForegroundColor Green }
        "S" { Write-Host "  [Skipped]" -ForegroundColor DarkGray }
        default {
            Write-Host "  [!] '$choice' is not valid. Options: R, C, or S." -ForegroundColor Yellow
            Write-Host "      Command was NOT run. Copy it manually if needed:" -ForegroundColor DarkGray
            Write-Host "  $cmd" -ForegroundColor DarkGreen
        }
    }
}

function ai-clip {
    <#
    .SYNOPSIS
    Analyse whatever text is in your clipboard.
    .EXAMPLE
    ai-clip                            ← explains clipboard content
    ai-clip "translate this to French"
    ai-clip "find all bugs in this code"
    #>
    param([string]$Question = "Explain and analyse this content clearly.")
    _SC-Track "ai-clip"
    $clip = [string](Get-Clipboard -Raw -EA SilentlyContinue)
    if ([string]::IsNullOrWhiteSpace($clip)) {
        Write-Host ""
        Write-Host "  [!] Your clipboard is empty." -ForegroundColor Yellow
        Write-Host "      Copy some text first (Ctrl+C), then run  ai-clip  again." -ForegroundColor DarkGray
        Write-Host ""
        return
    }
    Write-Host ""; Write-Host "  [ ai-clip ] Analysing clipboard  ($($clip.Length) chars)..." -ForegroundColor DarkCyan
    Write-Host "  Preview: $($clip.Substring(0,[Math]::Min(100,$clip.Length)))..." -ForegroundColor DarkGray
    _SC-Ask -Prompt "$Question`n`nContent:`n───`n$(_SC-Trim $clip)`n───" | Out-Null
}

# ════════════════════════════════════════════════════════════════════════════
#  FILES & FOLDERS
# ════════════════════════════════════════════════════════════════════════════

function ai-sum {
    <#
    .SYNOPSIS
    Summarise any file — PDF, Word doc, plain text, or code.
    .EXAMPLE
    ai-sum "C:\Downloads\report.pdf"
    ai-sum ".\README.md"
    ai-sum "MyService.java"
    #>
    param([Parameter(Mandatory)][string]$Path)
    _SC-Track "ai-sum"
    Write-Host ""; Write-Host "  [ ai-sum ] Reading: $Path" -ForegroundColor DarkCyan
    $c = _SC-Trim (_SC-ReadFile $Path)
    if ([string]::IsNullOrWhiteSpace($c)) { return }   # _SC-ReadFile already printed the error
    $words = ($c -split '\s+' | Where-Object { $_ -ne "" }).Count
    Write-Host "  📊  $($c.Length) chars · ~$words words" -ForegroundColor DarkGray
    _SC-Ask -Prompt "Provide a clear structured summary. Include: main topic, key points, conclusions, and action items if any.`n`nDocument:`n───`n$c`n───" | Out-Null
}

function ai-file {
    <#
    .SYNOPSIS
    Ask any question about any file.
    .EXAMPLE
    ai-file "MyClass.java" "what does this class do?"
    ai-file "report.pdf"  "what were the main findings?"
    ai-file "config.json" "explain each setting"
    #>
    param(
        [Parameter(Mandatory,Position=0)][string]$Path,
        [Parameter(Mandatory,Position=1)][string]$Question
    )
    _SC-Track "ai-file"
    Write-Host ""; Write-Host "  [ ai-file ] $Question" -ForegroundColor DarkCyan
    $c = _SC-Trim (_SC-ReadFile $Path)
    if ([string]::IsNullOrWhiteSpace($c)) { return }
    Write-Host "  📊  $($c.Length) chars" -ForegroundColor DarkGray
    _SC-Ask -Prompt "Answer this question about the file: $Question`n`nFile content:`n───`n$c`n───" | Out-Null
}

function ai-folder {
    <#
    .SYNOPSIS
    Analyse every code file in a folder and explain what each one does.
    .EXAMPLE
    ai-folder "C:\Projects\MyApp\src"
    ai-folder "."
    #>
    param([Parameter(Mandatory)][string]$Path)
    _SC-Track "ai-folder"
    if (-not (Test-Path $Path -PathType Container)) {
        Write-Host ""
        Write-Host "  [✗] Directory not found: $Path" -ForegroundColor Red
        Write-Host "      Check the path — use Tab to autocomplete." -ForegroundColor DarkGray
        Write-Host "      Current directory: $(Get-Location)" -ForegroundColor DarkGray
        Write-Host ""
        return
    }
    $supported = @("*.java","*.py","*.ps1","*.js","*.ts","*.cs","*.xml","*.json",
                   "*.txt","*.md","*.html","*.css","*.yaml","*.yml","*.go","*.rb","*.rs","*.sh")
    $files = Get-ChildItem -Path $Path -Recurse -Include $supported -File -EA SilentlyContinue |
             Select-Object -First 30
    if ($files.Count -eq 0) {
        Write-Host ""
        Write-Host "  [~] No supported code files found in: $Path" -ForegroundColor Yellow
        Write-Host "      Supported: $($supported -join ', ')" -ForegroundColor DarkGray
        Write-Host "      If your files are there, check you typed the folder path correctly." -ForegroundColor DarkGray
        Write-Host ""
        return
    }
    Write-Host ""; Write-Host "  [ ai-folder ] Found $($files.Count) file(s) — analysing in batches..." -ForegroundColor DarkCyan
    _SC-WarnLowRAM

    $batch    = [System.Text.StringBuilder]::new()
    $batchNum = 0
    foreach ($f in $files) {
        $c = Get-Content $f.FullName -Raw -Encoding UTF8 -EA SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        $snippet = if ($c.Length -gt 3000) { $c.Substring(0, 3000) + "`n...(truncated)" } else { $c }
        $null = $batch.AppendLine("=== FILE: $($f.Name) ===`n$snippet`n")
        if ($batch.Length -gt 8000) {
            $batchNum++
            Write-Host "  ── Batch $batchNum ────────────────────────────────" -ForegroundColor DarkGray
            _SC-Ask -Prompt "For each file below, write one paragraph: purpose, main classes/functions, notable patterns.`n`n$($batch.ToString())" `
                    -FallbackPrompt "Briefly describe each file's purpose:`n$($batch.ToString().Substring(0,3000))" | Out-Null
            $batch.Clear() | Out-Null
        }
    }
    if ($batch.Length -gt 0) {
        $batchNum++
        Write-Host "  ── Batch $batchNum ────────────────────────────────" -ForegroundColor DarkGray
        _SC-Ask -Prompt "For each file below, write one paragraph: purpose, main classes/functions, notable patterns.`n`n$($batch.ToString())" `
                -FallbackPrompt "Briefly describe each file's purpose:`n$($batch.ToString().Substring(0,[math]::Min(3000,$batch.Length)))" | Out-Null
    }
}

function ai-copy {
    <#
    .SYNOPSIS
    Copy a file's text content to your clipboard.
    .EXAMPLE
    ai-copy "MyClass.java"
    ai-copy "C:\Downloads\notes.txt"
    #>
    param([Parameter(Mandatory)][string]$Path)
    _SC-Track "ai-copy"
    $c = _SC-ReadFile $Path
    if ([string]::IsNullOrWhiteSpace($c)) { return }
    Set-Clipboard -Value $c
    Write-Host ""; Write-Host "  [✓] Copied $($c.Length) chars from '$([System.IO.Path]::GetFileName($Path))' to clipboard." -ForegroundColor Green
    Write-Host "      Now you can: paste it anywhere, or run  ai-clip `"your question`"" -ForegroundColor DarkCyan
}

function ai-search {
    <#
    .SYNOPSIS
    Search for files by name, or search inside files for text.
    .EXAMPLE
    ai-search "LoginPage"                      ← find files named LoginPage*
    ai-search "driver.findElement" -Content    ← find files containing that text
    ai-search "config" "C:\Projects"           ← search in a specific folder
    #>
    param(
        [Parameter(Mandatory)][string]$Query,
        [string]$Path = $PWD.Path,
        [switch]$Content
    )
    _SC-Track "ai-search"
    if (-not (Test-Path $Path -PathType Container)) {
        Write-Host "  [✗] Folder not found: $Path" -ForegroundColor Red
        Write-Host "      Current directory: $(Get-Location)" -ForegroundColor DarkGray
        return
    }
    Write-Host ""; Write-Host "  [ ai-search ] '$Query' in $Path" -ForegroundColor DarkCyan
    $nameResults = Get-ChildItem -Path $Path -Recurse -EA SilentlyContinue |
                   Where-Object { $_.Name -match [regex]::Escape($Query) } | Select-Object -First 20
    if ($nameResults.Count -gt 0) {
        Write-Host "  ── Files matching name ─────────────────────────────" -ForegroundColor Cyan
        foreach ($r in $nameResults) {
            $icon = if ($r.PSIsContainer) {"📁"} else {"📄"}
            Write-Host "  $icon $($r.FullName)" -ForegroundColor Green
        }
        Write-Host ""
    } else {
        Write-Host "  [~] No files found with '$Query' in the name." -ForegroundColor Yellow
        if (-not $Content) {
            Write-Host "      Tip: try  ai-search `"$Query`" -Content  to search inside files too." -ForegroundColor DarkGray
        }
    }
    if ($Content) {
        Write-Host "  ── Files containing that text ──────────────────────" -ForegroundColor Cyan
        $allFiles = Get-ChildItem $Path -Recurse -Include @("*.txt","*.java","*.py","*.md","*.xml",
                    "*.json","*.ps1","*.cs","*.js","*.html","*.ts","*.yaml","*.yml") -EA SilentlyContinue
        if ($allFiles.Count -eq 0) {
            Write-Host "  [~] No searchable files found in this folder." -ForegroundColor Yellow
        } else {
            $contentResults = Select-String -Path ($allFiles | Select-Object -ExpandProperty FullName) `
                              -Pattern ([regex]::Escape($Query)) -EA SilentlyContinue | Select-Object -First 15
            if ($contentResults.Count -gt 0) {
                foreach ($r in $contentResults) {
                    Write-Host "  📝 $($r.Path)" -NoNewline -ForegroundColor Green
                    Write-Host " (line $($r.LineNumber)): " -NoNewline -ForegroundColor DarkGray
                    Write-Host $r.Line.Trim() -ForegroundColor Gray
                }
            } else {
                Write-Host "  [~] No content matches for '$Query'." -ForegroundColor Yellow
                Write-Host "      Try a shorter keyword or check the spelling." -ForegroundColor DarkGray
            }
        }
    }
    Write-Host ""
}

function ai-fix {
    <#
    .SYNOPSIS
    Let AI find and fix all bugs in a code file. Original is backed up automatically.
    .EXAMPLE
    ai-fix "LoginTest.java"
    ai-fix "C:\Projects\src\MyService.py"
    #>
    param([Parameter(Mandatory)][string]$Path)
    _SC-Track "ai-fix"
    Write-Host ""; Write-Host "  [ ai-fix ] Fixing: $Path" -ForegroundColor DarkCyan
    $original = _SC-ReadFile $Path
    if ([string]::IsNullOrWhiteSpace($original)) { return }
    Write-Host "  Generating fix (this may take 30–60 s)..." -ForegroundColor DarkGray
    $raw   = _SC-Ask -Prompt "Fix ALL bugs in this code. Return ONLY the complete corrected file — no explanation, no markdown, no comments about what you changed.`n`nFile: $([System.IO.Path]::GetFileName($Path))`n$(_SC-Trim $original)" `
                     -System "You are an expert developer. Return only the corrected raw code. No markdown fences." -Temp 0.1 -Silent
    $fixed = _SC-StripFences $raw
    if ([string]::IsNullOrWhiteSpace($fixed)) {
        Write-Host ""
        Write-Host "  [✗] AI returned an empty response — no fix was generated." -ForegroundColor Red
        Write-Host "      What you can try:" -ForegroundColor DarkGray
        Write-Host "        ai-debug `"$Path`"   ← get a list of bugs instead (less memory)" -ForegroundColor Cyan
        Write-Host "        ai-stop              ← free memory, then retry ai-fix" -ForegroundColor Cyan
        Write-Host ""
        return
    }
    $backup = "$Path.bak_$(Get-Date -Format 'yyyyMMddHHmmss')"
    try {
        Copy-Item $Path $backup -EA Stop
        Write-Host "  [✓] Backup saved: $backup" -ForegroundColor DarkGray
    } catch {
        Write-Host "  [!] Could not create backup: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "      Proceeding WITHOUT a backup. Your original file may be overwritten." -ForegroundColor Yellow
    }
    Write-Host "  Original: $(($original -split "`n").Count) lines  →  Fixed: $(($fixed -split "`n").Count) lines" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Write fixed code to file? [Y] Yes   [N] No" -ForegroundColor Yellow
    $choice = (Read-Host "  Choice").Trim().ToUpper()
    if ($choice -eq "Y") {
        $fixed | Set-Content $Path -Encoding UTF8
        Write-Host "  [✓] File updated: $Path" -ForegroundColor Green
        Write-Host "      Backup at:     $backup" -ForegroundColor DarkGray
    } else {
        Write-Host "  [Skipped] Your original file is unchanged." -ForegroundColor DarkGray
        if (Test-Path $backup) { Write-Host "      Backup at: $backup" -ForegroundColor DarkGray }
    }
}

# ════════════════════════════════════════════════════════════════════════════
#  MEDIA & WEB
# ════════════════════════════════════════════════════════════════════════════

function ai-img {
    <#
    .SYNOPSIS
    Describe or analyse an image or the first page of a PDF using vision AI.
    .DESCRIPTION
    Requires: Claude cloud mode (best), or a local vision model (moondream / llava).
    .EXAMPLE
    ai-img "screenshot.png"
    ai-img "diagram.png" "explain what this flowchart shows"
    ai-img "report.pdf"  "what chart is on this page?"
    #>
    param(
        [Parameter(Mandatory,Position=0)][string]$Path,
        [Parameter(Position=1)][string]$Question = "Describe this image in detail. If it is a UI screenshot, describe every element. If there is code or math, break it down step by step."
    )
    _SC-Track "ai-img"
    if (-not (Test-Path $Path)) {
        Write-Host ""
        Write-Host "  [✗] File not found: '$Path'" -ForegroundColor Red
        Write-Host "      Check the path — use Tab to autocomplete." -ForegroundColor DarkGray
        Write-Host ""
        return
    }
    Write-Host ""; Write-Host "  [ ai-img ] Analysing: $(Split-Path $Path -Leaf)" -ForegroundColor DarkCyan
    $ext             = [System.IO.Path]::GetExtension($Path).ToLower()
    $supportedImages = @(".png",".jpg",".jpeg",".webp",".bmp",".gif")

    $base64 = ""
    if ($ext -eq ".pdf") {
        Write-Host "  [~] PDF detected — rendering page 1 as image..." -ForegroundColor DarkGray
        $tempImg = Join-Path $env:TEMP "ai_pdf_temp.png"
        $out = python -c "import fitz,sys; doc=fitz.open(sys.argv[1]); pix=doc.load_page(0).get_pixmap(dpi=150); pix.save(sys.argv[2])" $Path $tempImg 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tempImg)) {
            Write-Host ""
            Write-Host "  [✗] Could not render the PDF to an image." -ForegroundColor Red
            Write-Host "      Fix: pip install PyMuPDF" -ForegroundColor Cyan
            Write-Host "      Alternative: convert your PDF to PNG first, then run  ai-img  again." -ForegroundColor DarkGray
            Write-Host ""
            return
        }
        $base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($tempImg))
    } elseif ($ext -in $supportedImages) {
        $base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
    } else {
        Write-Host ""
        Write-Host "  [✗] '$ext' is not a supported image format." -ForegroundColor Red
        Write-Host "      Supported: $($supportedImages -join ', ') and .pdf" -ForegroundColor DarkGray
        Write-Host "      Convert your file to PNG first, then retry." -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    $cfg = _SC-LoadConfig
    # ── Cloud vision (Anthropic) ──────────────────────────────────────────
    if ($cfg.AIMode -eq "cloud" -and $cfg.APIProvider -eq "anthropic") {
        if ([string]::IsNullOrWhiteSpace($cfg.APIKey)) {
            Write-Host "  [✗] No Anthropic API key. Run: ai-setup" -ForegroundColor Red; return
        }
        $body = @{
            model      = "claude-3-5-sonnet-20241022"
            max_tokens = 1024
            messages   = @(@{
                role    = "user"
                content = @(
                    @{ type = "image"; source = @{ type = "base64"; media_type = "image/png"; data = $base64 } }
                    @{ type = "text";  text   = $Question }
                )
            })
        } | ConvertTo-Json -Depth 15 -Compress
        try {
            $r = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" -Method POST `
                -Headers @{ "x-api-key" = $cfg.APIKey; "anthropic-version" = "2023-06-01"; "content-type" = "application/json" } `
                -Body $body -TimeoutSec 90 -EA Stop
            Write-Host ""; Write-Host $r.content[0].text -ForegroundColor Green; Write-Host ""
            return
        } catch {
            Write-Host "  [✗] Claude Vision error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "      If this is an auth error, run: ai-setup  to re-enter your key." -ForegroundColor DarkGray
            return
        }
    }

    # ── Cloud vision (OpenAI) ─────────────────────────────────────────────
    if ($cfg.AIMode -eq "cloud" -and $cfg.APIProvider -eq "openai") {
        if ([string]::IsNullOrWhiteSpace($cfg.APIKey)) {
            Write-Host "  [✗] No OpenAI API key. Run: ai-setup" -ForegroundColor Red; return
        }
        $body = @{
            model    = "gpt-4o"
            messages = @(@{
                role    = "user"
                content = @(
                    @{ type = "image_url"; image_url = @{ url = "data:image/png;base64,$base64" } }
                    @{ type = "text"; text = $Question }
                )
            })
        } | ConvertTo-Json -Depth 15 -Compress
        try {
            $r = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" -Method POST `
                -Headers @{ "Authorization" = "Bearer $($cfg.APIKey)"; "Content-Type" = "application/json" } `
                -Body $body -TimeoutSec 90 -EA Stop
            Write-Host ""; Write-Host $r.choices[0].message.content -ForegroundColor Green; Write-Host ""
            return
        } catch {
            Write-Host "  [✗] OpenAI Vision error: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }

    # ── Local vision model ────────────────────────────────────────────────
    if (-not (_SC-OllamaCheck)) { return }
    $available    = _SC-OllamaListModels
    $visionModels = @($available | Where-Object { $_ -match "llava|bakllava|moondream|minicpm|vision" })
    if ($visionModels.Count -gt 0) {
        $vModel = $visionModels[0]
        Write-Host "  [~] Using local vision model: $vModel" -ForegroundColor DarkGray
        _SC-FlushVRAM
        $body = @{ model=$vModel; prompt=$Question; images=@($base64); stream=$false } | ConvertTo-Json -Depth 10 -Compress
        try {
            $r = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST `
                -Body $body -ContentType "application/json" -TimeoutSec 120 -EA Stop
            Write-Host ""; Write-Host $r.response -ForegroundColor Green; Write-Host ""
        } catch {
            Write-Host "  [✗] Vision model crashed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "      Falling back to ai-ocr (text extraction only)..." -ForegroundColor Yellow
            ai-ocr $Path
        }
    } else {
        Write-Host ""
        Write-Host "  [!] No vision model is installed locally." -ForegroundColor Yellow
        Write-Host "  ── Options ──────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "   A) Install a local vision model:" -ForegroundColor Gray
        Write-Host "        ollama pull moondream   ← lightweight, fast" -ForegroundColor Cyan
        Write-Host "        ollama pull llava        ← more capable" -ForegroundColor Cyan
        Write-Host "   B) Switch to Claude cloud AI (best vision quality):" -ForegroundColor Gray
        Write-Host "        ai-setup  →  choose option 2 (Anthropic)" -ForegroundColor Cyan
        Write-Host "   C) Extract text only (no image understanding):" -ForegroundColor Gray
        Write-Host "        ai-ocr `"$Path`"" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Attempting ai-ocr as text fallback..." -ForegroundColor DarkGray
        ai-ocr $Path
    }
}

function ai-ocr {
    <#
    .SYNOPSIS
    Extract and summarise text from an image or scanned PDF using OCR.
    Requires: pip install easyocr pillow
    .EXAMPLE
    ai-ocr "screenshot.png"
    ai-ocr "scanned_notes.pdf"
    #>
    param([Parameter(Mandatory)][string]$Path)
    _SC-Track "ai-ocr"
    if (-not (Test-Path $Path)) {
        Write-Host "  [✗] File not found: $Path" -ForegroundColor Red; return
    }
    Write-Host ""; Write-Host "  [ ai-ocr ] Running OCR on: $(Split-Path $Path -Leaf)" -ForegroundColor DarkCyan
    $target = $Path
    if ([System.IO.Path]::GetExtension($Path).ToLower() -eq ".pdf") {
        Write-Host "  [~] Converting PDF page 1 to image..." -ForegroundColor DarkGray
        $target = Join-Path $env:TEMP "sc_ocr_temp.png"
        python -c "import fitz,sys; doc=fitz.open(sys.argv[1]); pix=doc.load_page(0).get_pixmap(dpi=150); pix.save(sys.argv[2])" $Path $target 2>&1 | Out-Null
        if (-not (Test-Path $target)) {
            Write-Host "  [✗] Could not convert PDF. Fix: pip install PyMuPDF" -ForegroundColor Red; return
        }
    }
    $pyScript = @"
import sys, warnings
warnings.filterwarnings("ignore")
try:
    import easyocr
    reader = easyocr.Reader(['en'], gpu=False, verbose=False)
    results = reader.readtext(sys.argv[1], detail=0)
    print('\n'.join(results))
except ModuleNotFoundError:
    print("MISSING_MODULE")
except Exception as e:
    print(f"OCR_ERROR:{e}")
"@
    $tmp     = Join-Path $env:TEMP "sc_ocr.py"
    $pyScript | Set-Content $tmp -Encoding UTF8
    $ocrText = (python $tmp $target 2>&1 | Where-Object { $_ -notmatch "^(UserWarning|WARNING|INFO|CUDA)" }) -join "`n"

    if ($ocrText -match "MISSING_MODULE") {
        Write-Host ""
        Write-Host "  [✗] EasyOCR is not installed." -ForegroundColor Red
        Write-Host "      Fix: pip install easyocr pillow" -ForegroundColor Cyan
        Write-Host "      Note: first run downloads a ~100 MB model — this is normal." -ForegroundColor DarkGray
        Write-Host ""
        return
    }
    if ($ocrText -match "^OCR_ERROR:") {
        Write-Host "  [✗] OCR failed: $($ocrText -replace '^OCR_ERROR:','')" -ForegroundColor Red; return
    }
    if ([string]::IsNullOrWhiteSpace($ocrText)) {
        Write-Host "  [~] No text detected in the image." -ForegroundColor Yellow
        Write-Host "      If this is a handwritten or low-resolution image, OCR may not work." -ForegroundColor DarkGray
        return
    }
    Write-Host ""; Write-Host "  ── Extracted Text ────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host $ocrText -ForegroundColor Gray
    Write-Host "  ──────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""; Write-Host "  ── AI Summary ────────────────────────────────────────" -ForegroundColor DarkCyan
    _SC-AutoFlushIfNeeded
    _SC-Ask -Prompt "Summarise the key information from this OCR-extracted text:`n$ocrText" `
            -FallbackPrompt "What does this text say? Summarise it briefly:`n$($ocrText.Substring(0,[math]::Min(2000,$ocrText.Length)))" | Out-Null
}

function ai-web {
    <#
    .SYNOPSIS
    Fetch any webpage and ask a question about it.
    .EXAMPLE
    ai-web "https://selenium.dev/documentation"
    ai-web "https://docs.spring.io" "what is Spring Boot and how do I start a project?"
    #>
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$Question = "Summarise this page: main purpose, key information, and important actions."
    )
    _SC-Track "ai-web"
    if ($Url -notmatch '^https?://') { $Url = "https://$Url" }
    Write-Host ""; Write-Host "  [ ai-web ] Fetching: $Url" -ForegroundColor DarkCyan
    try {
        $html = (Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 20 -EA Stop).Content
    } catch {
        $e = $_.Exception.Message
        Write-Host "  [✗] Could not fetch that URL." -ForegroundColor Red
        if ($e -match "timeout") {
            Write-Host "      The site took too long to respond (> 20 s)." -ForegroundColor DarkGray
            Write-Host "      Try again, or check your internet connection." -ForegroundColor DarkGray
        } elseif ($e -match "403|Forbidden") {
            Write-Host "      The site blocked the request (403 Forbidden)." -ForegroundColor DarkGray
            Write-Host "      Some sites block automated access — try a different URL." -ForegroundColor DarkGray
        } else {
            Write-Host "      Detail: $e" -ForegroundColor DarkGray
        }
        return
    }
    $text = $html -replace '<script[^>]*>[\s\S]*?</script>', '' `
                  -replace '<style[^>]*>[\s\S]*?</style>', '' `
                  -replace '<[^>]+>', ' ' -replace '&nbsp;', ' ' -replace '&amp;', '&' `
                  -replace '&lt;', '<' -replace '&gt;', '>' -replace '\s{2,}', ' '
    Write-Host "  📊  $($text.Length) chars extracted" -ForegroundColor DarkGray
    _SC-Ask -Prompt "$Question`n`nPage ($Url):`n───`n$(_SC-Trim $text 10000)`n───" | Out-Null
}

function ai-weather {
    <#
    .SYNOPSIS
    Current weather + 3-day forecast + air quality for your configured city.
    Set your city with: ai-setup
    .EXAMPLE
    ai-weather
    #>
    _SC-Track "ai-weather"
    $cfg  = _SC-LoadConfig
    $city = $cfg.City
    if ([string]::IsNullOrWhiteSpace($city)) {
        Write-Host ""
        Write-Host "  [!] No city is configured." -ForegroundColor Yellow
        Write-Host "      Fix: ai-setup  →  enter your city name at step 4." -ForegroundColor Cyan
        Write-Host ""
        return
    }
    Write-Host ""; Write-Host "  [ ai-weather · $city ]" -ForegroundColor DarkCyan
    try {
        $data = Invoke-RestMethod -Uri "https://wttr.in/$([Uri]::EscapeDataString($city))?format=j1" -TimeoutSec 10 -EA Stop
        $cur  = $data.current_condition[0]
        $desc = $cur.weatherDesc[0].value
        $temp = $cur.temp_C; $feel = $cur.FeelsLikeC; $hum = $cur.humidity
        $wind = $cur.windspeedKmph; $vis  = $cur.visibility
        $lat  = $data.nearest_area[0].latitude; $lon = $data.nearest_area[0].longitude
        $icon = switch -Wildcard ($desc.ToLower()) {
            "*sun*"   {"☀️ "} "*clear*" {"🌤 "} "*cloud*" {"☁️ "}
            "*rain*"  {"🌧 "} "*storm*" {"⛈ "} "*snow*"  {"❄️ "}
            "*fog*"   {"🌫 "} "*mist*"  {"🌫 "} "*haze*"  {"🌫 "} default {"🌡 "}
        }
        Write-Host ""; Write-Host "  $icon $desc" -ForegroundColor Cyan
        Write-Host "  🌡  Temp       : ${temp}°C  (feels like ${feel}°C)" -ForegroundColor White
        Write-Host "  💧  Humidity   : ${hum}%" -ForegroundColor Blue
        Write-Host "  💨  Wind       : ${wind} km/h" -ForegroundColor Gray
        Write-Host "  👁  Visibility : ${vis} km" -ForegroundColor DarkGray
        try {
            $air    = Invoke-RestMethod -Uri "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=pm2_5,european_aqi" -TimeoutSec 5 -EA Stop
            $aqi    = $air.current.european_aqi
            $pm25   = $air.current.pm2_5
            $label  = switch ($true) {
                {$aqi -le 20}  {"Good"} {$aqi -le 40} {"Fair"}      {$aqi -le 60}  {"Moderate"}
                {$aqi -le 80}  {"Poor"} {$aqi -le 100}{"Very Poor"} default         {"Hazardous"}
            }
            $acolor = if ($aqi -le 40) {"Green"} elseif ($aqi -le 80) {"Yellow"} elseif ($aqi -le 100) {"DarkYellow"} else {"Red"}
            Write-Host "  ☢  AQI        : $aqi ($label)  PM2.5: $pm25 µg/m³" -ForegroundColor $acolor
        } catch {
            Write-Host "  ☢  AQI        : Unavailable (air quality API offline)" -ForegroundColor DarkGray
        }
        Write-Host "  📍 $city" -ForegroundColor DarkCyan; Write-Host ""
        Write-Host "  ── 3-Day Forecast ────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($day in $data.weather) {
            $date  = [datetime]::ParseExact($day.date,"yyyy-MM-dd",$null).ToString("ddd dd MMM")
            $maxC  = $day.maxtempC; $minC = $day.mintempC
            $desc2 = $day.hourly[4].weatherDesc[0].value
            $rain  = $day.hourly[4].chanceofrain
            $icon2 = switch -Wildcard ($desc2.ToLower()) {
                "*sun*"   {"☀️ "} "*clear*" {"🌤 "} "*cloud*" {"☁️ "}
                "*rain*"  {"🌧 "} "*storm*" {"⛈ "} "*snow*"  {"❄️ "} default {"🌡 "}
            }
            Write-Host "  $icon2 $($date.PadRight(14)) ↑${maxC}°  ↓${minC}°  💧$rain%  $desc2" -ForegroundColor Gray
        }
        Write-Host ""
    } catch {
        Write-Host ""
        Write-Host "  [✗] Could not fetch weather for '$city'." -ForegroundColor Red
        Write-Host "      Possible reasons:" -ForegroundColor DarkGray
        Write-Host "        • City name is wrong — use the English Google Maps spelling." -ForegroundColor DarkGray
        Write-Host "        • No internet connection." -ForegroundColor DarkGray
        Write-Host "      Fix the city name: ai-setup  →  step 4." -ForegroundColor Cyan
        Write-Host ""
    }
}

function ai-open {
    <#
    .SYNOPSIS
    Open any app, folder, or website by name. Falls back to Google search.
    .EXAMPLE
    ai-open brave
    ai-open youtube
    ai-open "C:\Projects"
    ai-open vscode
    #>
    param([Parameter(Mandatory)][string]$Target)
    _SC-Track "ai-open"
    $t = $Target.ToLower().Trim()
    if ($Target -match '^https?://') {
        Start-Process $Target; Write-Host "  [✓] Opened: $Target" -ForegroundColor Green; return
    }
    if ($Global:SC_URLS.ContainsKey($t)) {
        Start-Process $Global:SC_URLS[$t]; Write-Host "  [✓] Browser → $($Global:SC_URLS[$t])" -ForegroundColor Green; return
    }
    if ($Global:SC_APPS.ContainsKey($t)) {
        foreach ($p in $Global:SC_APPS[$t]) {
            if ($p -match '\*') {
                $resolved = Get-ChildItem (Split-Path $p -Parent) -Recurse -EA SilentlyContinue |
                    Where-Object { $_.Name -like (Split-Path $p -Leaf) -and -not $_.PSIsContainer } |
                    Select-Object -First 1
                if ($resolved) { Start-Process $resolved.FullName; Write-Host "  [✓] Launched: $t" -ForegroundColor Green; return }
            }
            if (Test-Path $p -PathType Leaf) { Start-Process $p; Write-Host "  [✓] Launched: $t" -ForegroundColor Green; return }
        }
        try { Start-Process $Global:SC_APPS[$t][0]; Write-Host "  [✓] Launched: $t" -ForegroundColor Green; return } catch {}
    }
    if (Test-Path $Target) { Start-Process $Target; Write-Host "  [✓] Opened: $(Split-Path $Target -Leaf)" -ForegroundColor Green; return }
    $found = Get-Command $Target -EA SilentlyContinue
    if ($found) { Start-Process $found.Source; Write-Host "  [✓] Launched: $Target" -ForegroundColor Green; return }
    try {
        $uwp = Get-StartApps -EA SilentlyContinue | Where-Object { $_.Name -match $Target } | Select-Object -First 1
        if ($uwp) { Start-Process "explorer.exe" "shell:AppsFolder\$($uwp.AppID)"; Write-Host "  [✓] Store App: $($uwp.Name)" -ForegroundColor Green; return }
    } catch {}
    Write-Host "  [~] '$Target' not found locally. Opening Google search..." -ForegroundColor Yellow
    Write-Host "      Tip: known apps you can open: $($Global:SC_APPS.Keys -join ', ')" -ForegroundColor DarkGray
    Write-Host "      Known sites: $($Global:SC_URLS.Keys -join ', ')" -ForegroundColor DarkGray
    Start-Process "https://www.google.com/search?q=$([Uri]::EscapeDataString($Target))"
}

# ════════════════════════════════════════════════════════════════════════════
#  CODE QUALITY
# ════════════════════════════════════════════════════════════════════════════

function ai-qa {
    <#
    .SYNOPSIS
    Generate production-ready test automation boilerplate from a description.
    Outputs: Cucumber feature file + Step Definitions + Page Object + TestNG runner.
    .EXAMPLE
    ai-qa "user login with valid credentials"
    ai-qa "add product to cart and checkout"
    #>
    param([Parameter(Mandatory)][string]$Description)
    _SC-Track "ai-qa"
    $cfg  = _SC-LoadConfig
    $role = if (-not [string]::IsNullOrWhiteSpace($cfg.Role)) { $cfg.Role } else { "Java SDET" }
    Write-Host ""; Write-Host "  [ ai-qa ] Generating test automation for:" -ForegroundColor DarkCyan
    Write-Host "  $Description" -ForegroundColor White; Write-Host ""
    _SC-Ask -Prompt "Generate complete production-ready test automation for: `"$Description`"`n`nInclude: 1. Gherkin .feature file  2. Step Definitions class  3. Page Object Model class  4. TestNG runner config.`nUse: explicit waits, POM pattern, proper package structure.`nTech stack: $role" `
            -FallbackPrompt "Write a Cucumber feature file and step definitions class for: $Description" | Out-Null
}

function ai-debug {
    <#
    .SYNOPSIS
    Analyse a code file for bugs. Returns line number, description, and fix for each.
    .EXAMPLE
    ai-debug "LoginTest.java"
    ai-debug ".\src\utils\Helper.py"
    #>
    param([Parameter(Mandatory)][string]$Path)
    _SC-Track "ai-debug"
    Write-Host ""; Write-Host "  [ ai-debug ] Analysing: $Path" -ForegroundColor DarkCyan
    $c = _SC-Trim (_SC-ReadFile $Path)
    if ([string]::IsNullOrWhiteSpace($c)) { return }
    _SC-Ask -Prompt "Expert code debugger. For each issue found: line number, description, corrected snippet.`nFile: $([System.IO.Path]::GetFileName($Path))`n───`n$c`n───" `
            -FallbackPrompt "List bugs in this code with line numbers:`n$($c.Substring(0,[math]::Min(4000,$c.Length)))" | Out-Null
}

function ai-test {
    <#
    .SYNOPSIS
    Generate comprehensive unit tests for any code file.
    Covers: happy path, edge cases, null inputs, exceptions.
    .EXAMPLE
    ai-test "UserService.java"
    ai-test "calculator.py"
    #>
    param([Parameter(Mandatory)][string]$Path)
    _SC-Track "ai-test"
    Write-Host ""; Write-Host "  [ ai-test ] Generating tests for: $Path" -ForegroundColor DarkCyan
    $c = _SC-Trim (_SC-ReadFile $Path) 10000
    if ([string]::IsNullOrWhiteSpace($c)) { return }
    _SC-Ask -Prompt "Generate comprehensive unit tests. Cover: happy path, edge cases, null inputs, exceptions. Use descriptive test names.`n───`n$c`n───" `
            -FallbackPrompt "Write 5 unit tests for this code:`n$($c.Substring(0,[math]::Min(3000,$c.Length)))" | Out-Null
}

function ai-review {
    <#
    .SYNOPSIS
    Senior-level code review: SOLID, naming, readability, security, test coverage.
    .EXAMPLE
    ai-review "MyService.java"
    ai-review "api_handler.py"
    #>
    param([Parameter(Mandatory)][string]$Path)
    _SC-Track "ai-review"
    Write-Host ""; Write-Host "  [ ai-review ] Senior review: $Path" -ForegroundColor DarkCyan
    $c = _SC-Trim (_SC-ReadFile $Path)
    if ([string]::IsNullOrWhiteSpace($c)) { return }
    _SC-Ask -Prompt @"
Senior code review. Be direct. Give line references where possible.
Cover:
1. Naming conventions
2. SOLID principles violations
3. Readability and maintainability
4. Test coverage gaps
5. Performance concerns
6. Security issues (if applicable)

File: $([System.IO.Path]::GetFileName($Path))
───
$c
───
"@ -FallbackPrompt "Review this code for quality issues:`n$($c.Substring(0,[math]::Min(4000,$c.Length)))" | Out-Null
}

# ════════════════════════════════════════════════════════════════════════════
#  GIT WORKFLOW
# ════════════════════════════════════════════════════════════════════════════

function _SC-GitCheck {
    # Returns $true if inside a git repo, prints fix guide and returns $false otherwise
    $check = git rev-parse --is-inside-work-tree 2>&1
    if ($check -ne "true") {
        Write-Host ""
        Write-Host "  [✗] You are not inside a Git repository." -ForegroundColor Red
        Write-Host "      Navigate to your project folder first:  cd C:\your\project" -ForegroundColor DarkGray
        Write-Host "      To start a new repo here:  git init" -ForegroundColor DarkGray
        Write-Host ""
        return $false
    }
    return $true
}

function ai-diff {
    <#
    .SYNOPSIS
    AI-powered review of your current Git changes (staged and unstaged).
    .EXAMPLE
    ai-diff
    #>
    _SC-Track "ai-diff"
    if (-not (_SC-GitCheck)) { return }
    $diff = ((git diff 2>&1) + "`n" + (git diff --staged 2>&1)).Trim()
    if ([string]::IsNullOrWhiteSpace($diff)) {
        Write-Host ""; Write-Host "  [~] No changes found — working tree is clean." -ForegroundColor Yellow
        Write-Host "      Make and save some edits first, then run  ai-diff  again." -ForegroundColor DarkGray; return
    }
    Write-Host ""; Write-Host "  [ ai-diff ] Reviewing Git changes..." -ForegroundColor DarkCyan
    _SC-Ask -Prompt "Senior code review of this Git diff. Cover: summary of changes, potential bugs, code quality issues, improvement suggestions.`n───`n$(_SC-Trim $diff 10000)`n───" `
            -FallbackPrompt "Summarise this Git diff in plain English:`n$(_SC-Trim $diff 4000)" | Out-Null
    Write-Host "  Tip: run  ai-commit  to generate a commit message from your staged changes." -ForegroundColor DarkCyan
}

function ai-commit {
    <#
    .SYNOPSIS
    Generate 2-3 Conventional Commit message suggestions from your staged diff.
    Stage files first: git add <file>
    .EXAMPLE
    ai-commit
    #>
    _SC-Track "ai-commit"
    if (-not (_SC-GitCheck)) { return }
    $diff = (git diff --staged 2>&1).Trim()
    if ([string]::IsNullOrWhiteSpace($diff)) {
        Write-Host ""
        Write-Host "  [~] No staged changes to generate a commit message from." -ForegroundColor Yellow
        Write-Host "      Stage your files first:" -ForegroundColor DarkGray
        Write-Host "        git add <filename>   ← stage a specific file" -ForegroundColor Cyan
        Write-Host "        git add .            ← stage everything" -ForegroundColor Cyan
        Write-Host "      Then run  ai-commit  again." -ForegroundColor DarkGray
        Write-Host ""
        return
    }
    Write-Host ""; Write-Host "  [ ai-commit ] Generating commit messages..." -ForegroundColor DarkCyan
    $s = _SC-StripFences (_SC-Ask -Prompt "Write 2-3 Conventional Commits messages for this diff. Format: type(scope): summary (under 72 chars, imperative mood). Rank best to worst.`n───`n$(_SC-Trim $diff 8000)`n───" `
                                  -System "Return only commit messages, one per line, ranked best to worst. No extra text." -Silent)
    if ([string]::IsNullOrWhiteSpace($s)) {
        Write-Host "  [!] Could not generate messages. Check your AI connection." -ForegroundColor Yellow; return
    }
    Write-Host ""; Write-Host $s -ForegroundColor Green
    Write-Host ""; Write-Host '  Copy one and run: git commit -m "your chosen message"' -ForegroundColor DarkCyan; Write-Host ""
}

function ai-git-push {
    <#
    .SYNOPSIS
    All-in-one: stage everything → generate commit message → commit → push.
    .EXAMPLE
    ai-git-push
    #>
    _SC-Track "ai-git-push"
    if (-not (_SC-GitCheck)) { return }
    $status = (git status --porcelain 2>&1).Trim()
    if ([string]::IsNullOrWhiteSpace($status)) {
        Write-Host ""; Write-Host "  [~] Nothing to commit — working tree is clean." -ForegroundColor Yellow; return
    }
    Write-Host ""; Write-Host "  [ ai-git-push ]" -ForegroundColor DarkCyan
    Write-Host "  ── Changed files ──────────────────────────────────" -ForegroundColor DarkGray
    git status --short | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
    git add .
    $diff = _SC-Trim (git diff --staged 2>&1) 8000
    Write-Host "  Generating commit message..." -ForegroundColor DarkGray
    $msg = _SC-StripFences (_SC-Ask -Prompt "Write ONE Conventional Commits message for this diff. Format: type(scope): summary (under 72 chars, imperative mood). Return ONLY the commit message.`n───`n$diff`n───" `
                                    -System "Return only the commit message. Nothing else." -Silent)
    if ([string]::IsNullOrWhiteSpace($msg)) {
        Write-Host ""
        Write-Host "  [!] Could not generate a commit message." -ForegroundColor Yellow
        Write-Host "      Your files are staged. You can commit manually:" -ForegroundColor DarkGray
        Write-Host "        git commit -m `"your message here`"" -ForegroundColor Cyan
        Write-Host "        git push" -ForegroundColor Cyan
        Write-Host ""
        return
    }
    Write-Host ""; Write-Host "  Suggested message: " -NoNewline -ForegroundColor Gray
    Write-Host $msg -ForegroundColor Green; Write-Host ""
    Write-Host "  [Y] Commit + Push   [E] Edit message first   [S] Skip" -ForegroundColor Yellow
    $choice = (Read-Host "  Choice").Trim().ToUpper()
    switch ($choice) {
        "Y" {
            git commit -m $msg
            $pushOut = git push 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [✓] Pushed to $(git remote get-url origin 2>$null)" -ForegroundColor Green
            } else {
                Write-Host "  [✗] Push failed." -ForegroundColor Red
                Write-Host "      Common causes:" -ForegroundColor DarkGray
                Write-Host "        • No remote set:  git remote add origin <url>" -ForegroundColor DarkGray
                Write-Host "        • Auth issue:     check your GitHub credentials" -ForegroundColor DarkGray
                Write-Host "        • Branch behind:  git pull --rebase first" -ForegroundColor DarkGray
                Write-Host "      Error detail: $pushOut" -ForegroundColor DarkGray
            }
        }
        "E" {
            Write-Host "  Your message: " -NoNewline -ForegroundColor Yellow
            $custom = Read-Host
            if ([string]::IsNullOrWhiteSpace($custom)) {
                Write-Host "  [!] No message entered. Files remain staged." -ForegroundColor Yellow
                Write-Host "      Run: git commit -m `"your message`"  when ready." -ForegroundColor DarkGray
                return
            }
            git commit -m $custom
            $pushOut = git push 2>&1
            if ($LASTEXITCODE -eq 0) { Write-Host "  [✓] Pushed." -ForegroundColor Green }
            else { Write-Host "  [✗] Push failed: $pushOut" -ForegroundColor Red }
        }
        "S" { Write-Host "  [Skipped] Files are staged. Run: git reset HEAD  to unstage." -ForegroundColor DarkGray }
        default {
            Write-Host "  [!] '$choice' is not valid. Options: Y, E, or S." -ForegroundColor Yellow
            Write-Host "      Files are staged. Run  ai-git-push  again to retry." -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

# ════════════════════════════════════════════════════════════════════════════
#  INTERVIEW PREP ARSENAL
# ════════════════════════════════════════════════════════════════════════════

function ai-visual {
    <#
    .SYNOPSIS
    Generate an ASCII flow diagram for any concept or process.
    .EXAMPLE
    ai-visual "how HTTP works"
    ai-visual "Selenium WebDriver lifecycle" -Fancy
    ai-visual "CI/CD pipeline"
    #>
    param([Parameter(Mandatory)][string]$Topic, [switch]$Fancy)
    _SC-Track "ai-visual"
    Write-Host ""; Write-Host "  [ ai-visual ] Diagramming: $Topic" -ForegroundColor DarkCyan
    $p1D = "Explain `"$Topic`" as a single horizontal flow: [ Step ] ──► [ Step ] ──► [ End ]. Max 5 steps. Add one bullet per step. No markdown fences."
    $p2D = "Explain `"$Topic`" as a horizontal box diagram using box-drawing chars. Max 4 boxes. Labels under 10 chars. No markdown fences."
    $primary = if ($Fancy) { $p2D } else { $p1D }
    _SC-Ask -Prompt $primary -FallbackPrompt $p1D | Out-Null
}

function ai-mindmap {
    <#
    .SYNOPSIS
    Generate a full study guide + ASCII mind map tree for any topic.
    .EXAMPLE
    ai-mindmap "Selenium WebDriver"
    ai-mindmap "Java Collections Framework"
    ai-mindmap "REST API design"
    #>
    param([Parameter(Mandatory)][string]$Topic)
    _SC-Track "ai-mindmap"
    Write-Host ""; Write-Host "  [ ai-mindmap ] Mapping: $Topic" -ForegroundColor DarkCyan
    _SC-Ask -Prompt @"
Create a comprehensive study guide for: "$Topic"

Format:
📚 OVERVIEW: [2-3 sentence summary]

$Topic
├── Core Concept 1
│   ├── Sub-topic A
│   │   └── specific detail
│   └── Sub-topic B
│       └── specific detail
├── Core Concept 2
│   └── ...
└── Core Concept 3
    └── ...

💡 KEY INSIGHT: [one sentence takeaway]

Rules: 5-7 main branches. Deep 3rd tier with specifics. No markdown code blocks.
"@ -FallbackPrompt "Explain the key concepts of $Topic as a structured list." | Out-Null
}

function ai-interview {
    <#
    .SYNOPSIS
    Single-question mock interview with AI grading and model answer.
    .EXAMPLE
    ai-interview "java"
    ai-interview "selenium"
    ai-interview "system design"
    #>
    param([string]$Topic = "software development")
    _SC-Track "ai-interview"
    $cfg = _SC-LoadConfig
    if ($cfg.AIMode -eq "local" -and -not (_SC-OllamaCheck)) { return }
    Write-Host ""; Write-Host "  [ MOCK INTERVIEW · $($Topic.ToLower()) ]" -ForegroundColor Magenta
    Write-Host "  Answer naturally · press Enter twice when done." -ForegroundColor DarkGray; Write-Host ""
    $question = _SC-Ask -Prompt "Ask ONE specific interview question about: $Topic. Ask ONLY the question — no intro, no numbering, no explanation." `
                        -System "You are a senior interviewer. Return only the question. Nothing else." -Silent
    if ([string]::IsNullOrWhiteSpace($question)) {
        Write-Host "  [!] Could not generate a question. Check your AI connection." -ForegroundColor Yellow; return
    }
    Write-Host "  ❓ " -NoNewline -ForegroundColor Yellow; Write-Host $question.Trim() -ForegroundColor White; Write-Host ""
    Write-Host "  Your answer (press Enter twice when done):" -ForegroundColor DarkCyan
    $lines = @()
    while ($true) {
        $line = Read-Host "  ›"
        if ($line -eq "" -and $lines.Count -gt 0) { break }
        $lines += $line
    }
    $answer = ($lines -join " ").Trim()
    if ([string]::IsNullOrWhiteSpace($answer)) {
        Write-Host "  [~] No answer given — session ended." -ForegroundColor DarkGray; return
    }
    Write-Host ""; Write-Host "  [ Grading... ]" -ForegroundColor DarkCyan
    _SC-Ask -Prompt "Grade this interview answer.`n`nQuestion: $question`nAnswer: $answer`n`nProvide: 1. Score X/10  2. What was GOOD  3. What was MISSING  4. Model Answer (3-5 sentences)  5. One tip to improve" `
            -FallbackPrompt "Score this answer 1-10 and explain briefly. Q: $question A: $answer" | Out-Null
}

function ai-mock {
    <#
    .SYNOPSIS
    Full 5-question mock interview session with a scored final verdict.
    .EXAMPLE
    ai-mock "java backend developer"
    ai-mock "python data engineer"
    ai-mock "devops engineer"
    #>
    param([string]$Topic = "software developer")
    _SC-Track "ai-mock"
    $cfg = _SC-LoadConfig
    if ($cfg.AIMode -eq "local" -and -not (_SC-OllamaCheck)) { return }
    Write-Host ""; Write-Host "  [ FULL MOCK INTERVIEW · $Topic · 5 questions ]" -ForegroundColor Magenta
    Write-Host "  HR + Technical mix · scored at the end." -ForegroundColor DarkGray; Write-Host ""
    Write-Host "  Press Enter to start..."; Read-Host | Out-Null
    Write-Host ""; Write-Host "  Preparing 5 questions..." -ForegroundColor DarkGray

    $qRaw = _SC-Ask -Prompt @"
Generate exactly 5 interview questions for this role: $Topic
Mix: Q1=HR/behavioral, Q2=core technical concept, Q3=tool/framework specific, Q4=testing/quality, Q5=scenario/problem-solving.
Return ONLY the 5 questions, numbered 1-5, one per line. No extra text, no explanations.
"@ -System "Return only 5 numbered questions. Nothing else." -Silent

    if ([string]::IsNullOrWhiteSpace($qRaw)) {
        Write-Host "  [!] Could not generate questions. Check your AI connection." -ForegroundColor Red; return
    }

    # Robust parser: any line that looks like a question (ends with ? or is long enough)
    $questions = @($qRaw.Trim() -split "`n" |
        ForEach-Object { ($_ -replace '^\d+[\.\)\:]\s*', '').Trim() } |
        Where-Object { $_.Length -gt 15 } |
        Select-Object -First 5)

    if ($questions.Count -lt 3) {
        Write-Host "  [!] Not enough questions were generated (got $($questions.Count))." -ForegroundColor Red
        Write-Host "      Try a more specific topic, or check your AI connection." -ForegroundColor DarkGray
        return
    }

    $answers = @()
    for ($i = 0; $i -lt $questions.Count; $i++) {
        Write-Host ""; Write-Host "  ── Question $($i+1) / $($questions.Count) ──────────────────────────────" -ForegroundColor Cyan
        Write-Host "  ❓ $($questions[$i])" -ForegroundColor White; Write-Host ""
        Write-Host "  Your answer (press Enter twice when done):" -ForegroundColor DarkGray
        $lines = @()
        while ($true) {
            $line = Read-Host "  ›"
            if ($line -eq "" -and $lines.Count -gt 0) { break }
            $lines += $line
        }
        $ans = ($lines -join " ").Trim()
        $answers += if ([string]::IsNullOrWhiteSpace($ans)) { "(no answer given)" } else { $ans }
        Write-Host "  [ Noted ]" -ForegroundColor DarkGray
    }

    Write-Host ""; Write-Host "  ── Grading your session... ──────────────────────────" -ForegroundColor DarkCyan; Write-Host ""
    $qaBlock = ""
    for ($i = 0; $i -lt $questions.Count; $i++) {
        $qaBlock += "Q$($i+1): $($questions[$i])`nA$($i+1): $($answers[$i])`n`n"
    }
    _SC-Ask -Prompt @"
Grade this mock interview for a: $Topic
$qaBlock
For each question:
Q[N] · Score X/10 · STRONG / OK / WEAK
Good: ...  Missing: ...  Ideal: ...

Then:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FINAL SCORE  : X / $($questions.Count * 10)
VERDICT      : READY TO APPLY / NEEDS MORE PREP / NOT READY YET
TOP WEAKNESS : (biggest gap)
FOCUS NEXT   : (2 specific things to study)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"@ -FallbackPrompt "Score these interview answers 1-10 each and give an overall verdict:`n$qaBlock" | Out-Null
    Write-Host ""
}

function ai-flashcard {
    <#
    .SYNOPSIS
    Spaced-repetition flashcard for any topic. Tracks score across sessions.
    .EXAMPLE
    ai-flashcard "java"
    ai-flashcard "sql"
    ai-flashcard "docker"
    #>
    param([string]$Topic = "software development")
    _SC-Track "ai-flashcard"
    $cfg = _SC-LoadConfig
    if ($cfg.AIMode -eq "local" -and -not (_SC-OllamaCheck)) { return }

    $statsFile = Join-Path $env:TEMP "sc_flashcards.json"
    $stats = @{}
    if (Test-Path $statsFile) {
        try {
            (Get-Content $statsFile -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties |
                ForEach-Object { $stats[$_.Name] = [int]$_.Value }
        } catch { $stats = @{} }
    }

    Write-Host ""; Write-Host "  [ FLASHCARD · $($Topic.ToLower()) ]" -ForegroundColor Cyan; Write-Host ""
    $q = _SC-Ask -Prompt "Generate ONE interview flashcard question about $Topic. Return only the question." `
                 -System "Return only the question. Nothing else." -Silent
    if ([string]::IsNullOrWhiteSpace($q)) {
        Write-Host "  [!] Could not generate a question. Check your AI connection." -ForegroundColor Red; return
    }
    Write-Host "  Q: " -NoNewline -ForegroundColor Yellow; Write-Host $q.Trim() -ForegroundColor White; Write-Host ""
    Write-Host "  Your answer: " -NoNewline -ForegroundColor DarkCyan
    $userAns = Read-Host

    $feedback = _SC-Ask -Prompt "Question: $q`nCandidate's Answer: $userAns`n`nRate: CORRECT, PARTIAL, or WRONG.`nFormat exactly as:`nVERDICT: [CORRECT/PARTIAL/WRONG]`nIDEAL: [ideal answer in 2-3 sentences]" `
                        -System "Return verdict and ideal answer in the exact format. Nothing else." -Silent
    $verdict  = if ($feedback -match "(?mi)^VERDICT:\s*(CORRECT|PARTIAL|WRONG)") { $Matches[1].ToUpper() } else { "UNKNOWN" }
    $ideal    = if ($feedback -match "(?mi)^IDEAL:\s*(.+)")                      { $Matches[1] } else { $feedback }
    $color    = switch ($verdict) { "CORRECT"{"Green"} "PARTIAL"{"Yellow"} default{"Red"} }
    $icon     = switch ($verdict) { "CORRECT"{"✅"} "PARTIAL"{"⚠️ "} default{"❌"} }

    Write-Host ""; Write-Host "  $icon Verdict: $verdict" -ForegroundColor $color
    Write-Host ""; Write-Host "  Ideal answer: $ideal" -ForegroundColor Gray

    $key = $Topic.ToLower()
    if (-not $stats.ContainsKey($key)) { $stats[$key] = 0 }
    if ($verdict -eq "CORRECT") { $stats[$key]++ }
    if ($verdict -eq "WRONG")   { $stats[$key] = [math]::Max(0, $stats[$key] - 1) }

    try { $stats | ConvertTo-Json -Compress | Set-Content $statsFile -Encoding UTF8 } catch {}

    Write-Host ""; Write-Host "  ── Your Scores ──────────────────────────────────────" -ForegroundColor DarkCyan
    $stats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        $bar = "█" * [math]::Min($_.Value, 20)
        Write-Host "  $($_.Key.PadRight(18)) $bar $($_.Value)" -ForegroundColor DarkGray
    }; Write-Host ""
}

function ai-explain {
    <#
    .SYNOPSIS
    Get a line-by-line breakdown of any code snippet or concept.
    .EXAMPLE
    ai-explain "@Override public boolean equals(Object obj) { ... }"
    ai-explain "HashMap vs LinkedHashMap"
    ai-explain "what is a race condition"
    #>
    param([Parameter(Mandatory)][string]$Input)
    _SC-Track "ai-explain"
    Write-Host ""; Write-Host "  [ ai-explain ] Breaking down..." -ForegroundColor DarkCyan
    _SC-Ask -Prompt @"
Explain this code or concept clearly.

Structure:
1. ONE sentence: what it is
2. ASCII visual showing how it works
3. Line-by-line breakdown (if code)
4. Why it matters in interviews
5. Common mistake or gotcha

Input:
───
$Input
───
"@ -FallbackPrompt "Explain this in simple terms with an example: $Input" | Out-Null
}

function ai-cheatsheet {
    <#
    .SYNOPSIS
    Generate a compact cheatsheet for any topic — great for quick revision.
    .EXAMPLE
    ai-cheatsheet "git commands"
    ai-cheatsheet "SQL joins"
    ai-cheatsheet "Java collections"
    ai-cheatsheet "Docker"
    #>
    param([Parameter(Mandatory)][string]$Topic)
    _SC-Track "ai-cheatsheet"
    Write-Host ""; Write-Host "  [ ai-cheatsheet ] Generating: $Topic" -ForegroundColor DarkCyan
    _SC-Ask -Prompt @"
Generate a compact terminal cheatsheet for: $Topic

Format:
- Emoji icons for categories
- Group into 4-6 sections
- Each entry: COMMAND/CONCEPT  →  what it does (under 70 chars)
- Top 20 most important things only
- End with: ⭐ 3 PRO TIPS

No markdown fences.
"@ -System "Be concise. Use emoji for categories. No markdown fences." | Out-Null
}

function ai-jd {
    <#
    .SYNOPSIS
    Analyse a Job Description for skill gaps, talking points, and likely interview questions.
    .EXAMPLE
    ai-jd                       ← paste JD interactively
    ai-jd "C:\Downloads\jd.txt"
    #>
    param([string]$Path = "")
    _SC-Track "ai-jd"
    $jd = ""
    if ($Path -ne "" -and (Test-Path $Path)) {
        $jd = _SC-ReadFile $Path
        if ([string]::IsNullOrWhiteSpace($jd)) { return }
        Write-Host ""; Write-Host "  [ ai-jd ] Reading: $Path" -ForegroundColor DarkCyan
    } else {
        Write-Host ""; Write-Host "  [ ai-jd ] Paste the job description below." -ForegroundColor DarkCyan
        Write-Host "  Press Enter twice when done." -ForegroundColor DarkGray; Write-Host ""
        $lines = @()
        while ($true) {
            $line = Read-Host "  ›"
            if ($line -eq "" -and $lines.Count -gt 0) { break }
            $lines += $line
        }
        $jd = $lines -join "`n"
    }
    if ([string]::IsNullOrWhiteSpace($jd)) {
        Write-Host "  [!] No job description provided." -ForegroundColor Yellow
        Write-Host "      Paste it interactively or pass a file path: ai-jd `"path\to\jd.txt`"" -ForegroundColor DarkGray
        return
    }
    $cfg  = _SC-LoadConfig
    $role = if (-not [string]::IsNullOrWhiteSpace($cfg.Role)) { $cfg.Role } else { "software developer" }
    Write-Host ""; Write-Host "  Analysing for a $role profile..." -ForegroundColor DarkGray
    _SC-Ask -Prompt @"
You are a career coach. The candidate is a $role.

Analyse this job description:
1. ✅ SKILLS YOU ALREADY HAVE (based on a typical $role background)
2. ⚠️  SKILL GAPS (list exact missing tools/frameworks — be specific)
3. 🎯 WHAT TO HIGHLIGHT (3-4 talking points for the opening of the interview)
4. ❓ TOP 8 INTERVIEW QUESTIONS (Technical + HR mix for this exact role)
5. 💡 ONE ACTION ITEM (most impactful thing to do before the interview)

Job Description:
───
$(_SC-Trim $jd 8000)
───
"@ -System "You are a career coach. Be specific, actionable, and honest." | Out-Null
}

# ════════════════════════════════════════════════════════════════════════════
#  NOTES & TODOS
# ════════════════════════════════════════════════════════════════════════════

function _SC-LoadJson {
    param([string]$Path, [string]$DefaultType = "array")
    if (-not (Test-Path $Path)) {
        return if ($DefaultType -eq "array") { @() } else { @{} }
    }
    try {
        $raw = Get-Content $Path -Raw -Encoding UTF8
        if ($DefaultType -eq "array") { return @(ConvertFrom-Json $raw) }
        else {
            $obj  = ConvertFrom-Json $raw
            $hash = @{}
            $obj.PSObject.Properties | ForEach-Object { $hash[$_.Name] = $_.Value }
            return $hash
        }
    } catch { return if ($DefaultType -eq "array") { @() } else { @{} } }
}

function _SC-SaveJson {
    param([string]$Path, $Data)
    try { $Data | ConvertTo-Json -Compress -Depth 5 | Set-Content $Path -Encoding UTF8 -Force }
    catch { Write-Host "  [!] Could not save data: $($_.Exception.Message)" -ForegroundColor Yellow }
}

function ai-note {
    <#
    .SYNOPSIS
    Save a quick note. All notes persist between sessions.
    .EXAMPLE
    ai-note "review ArrayDeque before interview tomorrow"
    ai-note "push feature/login-fix branch before 5pm"
    #>
    param([Parameter(Mandatory)][string]$Text)
    _SC-Track "ai-note"
    $f     = Join-Path $env:TEMP "sc_notes.json"
    $notes = _SC-LoadJson $f "array"
    $notes += [PSCustomObject]@{ id=($notes.Count+1); time=(Get-Date -Format "yyyy-MM-dd HH:mm"); text=$Text }
    _SC-SaveJson $f $notes
    Write-Host "  [✓] Note #$($notes.Count) saved: '$Text'" -ForegroundColor Green
}

function ai-notes {
    <#
    .SYNOPSIS
    List all saved notes.
    .EXAMPLE
    ai-notes
    #>
    $f     = Join-Path $env:TEMP "sc_notes.json"
    $notes = _SC-LoadJson $f "array"
    if ($notes.Count -eq 0) {
        Write-Host ""; Write-Host "  [~] No notes yet." -ForegroundColor Yellow
        Write-Host "      Save one: ai-note `"your note here`"" -ForegroundColor DarkGray; Write-Host ""; return
    }
    Write-Host ""; Write-Host "  ── Notes ($($notes.Count)) ──────────────────────────────────" -ForegroundColor Cyan
    foreach ($n in $notes) {
        Write-Host "  #$($n.id) " -NoNewline -ForegroundColor DarkCyan
        Write-Host "[$($n.time)] " -NoNewline -ForegroundColor DarkGray
        Write-Host $n.text -ForegroundColor White
    }
    Write-Host ""
}

function ai-note-clear {
    <#
    .SYNOPSIS
    Delete ALL saved notes permanently.
    .EXAMPLE
    ai-note-clear
    #>
    Write-Host "  Delete ALL notes permanently? [Y/N] " -NoNewline -ForegroundColor Yellow
    if ((Read-Host).Trim().ToUpper() -eq "Y") {
        Remove-Item (Join-Path $env:TEMP "sc_notes.json") -EA SilentlyContinue
        Write-Host "  [✓] All notes cleared." -ForegroundColor Green
    } else {
        Write-Host "  [Skipped] Notes are untouched." -ForegroundColor DarkGray
    }
}

function ai-todo {
    <#
    .SYNOPSIS
    Add a task to your persistent to-do list.
    .EXAMPLE
    ai-todo "finish Selenium grid config"
    ai-todo "read about TestNG data providers"
    #>
    param([Parameter(Mandatory)][string]$Task)
    _SC-Track "ai-todo"
    $f     = Join-Path $env:TEMP "sc_todos.json"
    $todos = _SC-LoadJson $f "array"
    $todos += [PSCustomObject]@{ id=($todos.Count+1); done=$false; time=(Get-Date -Format "yyyy-MM-dd HH:mm"); task=$Task }
    _SC-SaveJson $f $todos
    Write-Host "  [✓] TODO #$($todos.Count) added: $Task" -ForegroundColor Green
    Write-Host "      View your list: ai-todos  |  Mark done: ai-done <id>" -ForegroundColor DarkGray
}

function ai-todos {
    <#
    .SYNOPSIS
    View all to-do items (pending and completed).
    .EXAMPLE
    ai-todos
    #>
    $f     = Join-Path $env:TEMP "sc_todos.json"
    $todos = _SC-LoadJson $f "array"
    if ($todos.Count -eq 0) {
        Write-Host ""; Write-Host "  [~] No todos yet." -ForegroundColor Yellow
        Write-Host "      Add one: ai-todo `"your task here`"" -ForegroundColor DarkGray; Write-Host ""; return
    }
    $pending   = @($todos | Where-Object { -not $_.done })
    $completed = @($todos | Where-Object { $_.done })
    Write-Host ""; Write-Host "  ── Pending ($($pending.Count)) ────────────────────────────────" -ForegroundColor Cyan
    foreach ($t in $pending) {
        Write-Host "  ⬜ #$($t.id) $($t.task)" -ForegroundColor White
    }
    if ($completed.Count -gt 0) {
        Write-Host ""; Write-Host "  ── Completed ($($completed.Count)) ──────────────────────────────" -ForegroundColor DarkGray
        foreach ($t in $completed) {
            Write-Host "  ✅ #$($t.id) $($t.task)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""; Write-Host "  Mark done: ai-done <id>   |   Add task: ai-todo `"task`"" -ForegroundColor DarkCyan; Write-Host ""
}

function ai-done {
    <#
    .SYNOPSIS
    Mark a to-do item as complete by its ID number.
    .EXAMPLE
    ai-done 2
    ai-done 5
    #>
    param([Parameter(Mandatory)][int]$Id)
    $f     = Join-Path $env:TEMP "sc_todos.json"
    $todos = _SC-LoadJson $f "array"
    if ($todos.Count -eq 0) {
        Write-Host "  [~] No todos found. Add one: ai-todo `"task`"" -ForegroundColor Yellow; return
    }
    $t = $todos | Where-Object { $_.id -eq $Id }
    if ($null -eq $t) {
        Write-Host "  [!] TODO #$Id not found." -ForegroundColor Red
        Write-Host "      Run  ai-todos  to see all IDs." -ForegroundColor DarkGray; return
    }
    if ($t.done) {
        Write-Host "  [~] TODO #$Id is already marked done: '$($t.task)'" -ForegroundColor DarkGray; return
    }
    $t.done = $true
    _SC-SaveJson $f $todos
    Write-Host "  [✓] Done: $($t.task)" -ForegroundColor Green
    $remaining = @($todos | Where-Object { -not $_.done }).Count
    if ($remaining -gt 0) {
        Write-Host "  📋 $remaining task(s) still pending. Run  ai-todos  to see them." -ForegroundColor Yellow
    } else {
        Write-Host "  🎉 All tasks complete!" -ForegroundColor Green
    }
}

# ════════════════════════════════════════════════════════════════════════════
#  SNIPPETS
# ════════════════════════════════════════════════════════════════════════════

function ai-snippet {
    <#
    .SYNOPSIS
    Save, retrieve, list, or delete reusable code/text snippets.
    Retrieval auto-copies to clipboard.
    .EXAMPLE
    ai-snippet save "xpath-wait" "driver.findElement(By.xpath(...))"
    ai-snippet get  "xpath-wait"
    ai-snippet list
    ai-snippet delete "xpath-wait"
    #>
    param(
        [Parameter(Mandatory,Position=0)][string]$Action,
        [Parameter(Position=1)][string]$Name  = "",
        [Parameter(Position=2)][string]$Value = ""
    )
    _SC-Track "ai-snippet"
    $f    = Join-Path $env:TEMP "sc_snippets.json"
    $data = _SC-LoadJson $f "hash"

    switch ($Action.ToLower()) {
        { $_ -in "save","add" } {
            if ([string]::IsNullOrWhiteSpace($Name)) {
                Write-Host "  [!] You must provide a name." -ForegroundColor Red
                Write-Host "      Usage: ai-snippet save `"<name>`" `"<value>`"" -ForegroundColor DarkGray; return
            }
            $key = $Name.ToLower()
            if ($data.ContainsKey($key)) {
                Write-Host "  [!] A snippet named '$Name' already exists." -ForegroundColor Yellow
                Write-Host "  Overwrite it? [Y/N] " -NoNewline -ForegroundColor Yellow
                if ((Read-Host).Trim().ToUpper() -ne "Y") {
                    Write-Host "  [Skipped] Snippet unchanged." -ForegroundColor DarkGray; return
                }
            }
            if ([string]::IsNullOrWhiteSpace($Value)) {
                Write-Host "  Paste your snippet (press Enter twice when done):" -ForegroundColor DarkCyan
                $lines = @()
                while ($true) {
                    $l = Read-Host "  ›"
                    if ($l -eq "" -and $lines.Count -gt 0) { break }
                    $lines += $l
                }
                $Value = $lines -join "`n"
            }
            $data[$key] = $Value
            _SC-SaveJson $f $data
            Write-Host "  [✓] Snippet '$Name' saved." -ForegroundColor Green
            Write-Host "      Retrieve it: ai-snippet get `"$Name`"" -ForegroundColor DarkGray
        }
        { $_ -in "get","fetch" } {
            if ([string]::IsNullOrWhiteSpace($Name)) {
                Write-Host "  [!] You must provide a name." -ForegroundColor Red
                Write-Host "      Usage: ai-snippet get `"<name>`"" -ForegroundColor DarkGray
                Write-Host "      See all: ai-snippet list" -ForegroundColor DarkGray; return
            }
            $key = $Name.ToLower()
            if (-not $data.ContainsKey($key)) {
                Write-Host "  [!] No snippet named '$Name'." -ForegroundColor Red
                Write-Host "      Run: ai-snippet list  to see all saved snippets." -ForegroundColor DarkGray; return
            }
            $val = $data[$key]
            Set-Clipboard -Value $val
            Write-Host ""; Write-Host "  ── $Name ────────────────────────────────────────────" -ForegroundColor Cyan
            Write-Host $val -ForegroundColor Green
            Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host "  [✓] Copied to clipboard." -ForegroundColor DarkGray; Write-Host ""
        }
        { $_ -in "list","ls","all" } {
            if ($data.Count -eq 0) {
                Write-Host ""; Write-Host "  [~] No snippets saved yet." -ForegroundColor Yellow
                Write-Host "      Save one: ai-snippet save `"name`" `"value`"" -ForegroundColor DarkGray; Write-Host ""; return
            }
            Write-Host ""; Write-Host "  ── Snippets ($($data.Count)) ──────────────────────────────" -ForegroundColor Cyan
            $data.GetEnumerator() | Sort-Object Name | ForEach-Object {
                $preview = if ($_.Value.Length -gt 60) { $_.Value.Substring(0,60) + "…" } else { $_.Value }
                Write-Host "  📎 $($_.Key.PadRight(20))" -NoNewline -ForegroundColor Yellow
                Write-Host " $preview" -ForegroundColor Gray
            }
            Write-Host ""; Write-Host "  Retrieve: ai-snippet get `"<name>`"" -ForegroundColor DarkCyan; Write-Host ""
        }
        { $_ -in "delete","rm","remove" } {
            if ([string]::IsNullOrWhiteSpace($Name)) {
                Write-Host "  [!] You must provide a name." -ForegroundColor Red
                Write-Host "      Usage: ai-snippet delete `"<name>`"" -ForegroundColor DarkGray; return
            }
            $key = $Name.ToLower()
            if (-not $data.ContainsKey($key)) {
                Write-Host "  [!] No snippet named '$Name'." -ForegroundColor Red
                Write-Host "      Run: ai-snippet list  to see what's saved." -ForegroundColor DarkGray; return
            }
            $data.Remove($key)
            _SC-SaveJson $f $data
            Write-Host "  [✓] Snippet '$Name' deleted." -ForegroundColor Green
        }
        default {
            Write-Host "  [!] '$Action' is not a valid action." -ForegroundColor Red
            Write-Host "      Valid actions: save · get · list · delete" -ForegroundColor DarkGray
            Write-Host "      Examples:" -ForegroundColor DarkGray
            Write-Host "        ai-snippet save `"mycode`" `"System.out.println();`"" -ForegroundColor Cyan
            Write-Host "        ai-snippet get  `"mycode`"" -ForegroundColor Cyan
            Write-Host "        ai-snippet list" -ForegroundColor Cyan
            Write-Host "        ai-snippet delete `"mycode`"" -ForegroundColor Cyan
        }
    }
}

# ════════════════════════════════════════════════════════════════════════════
#  TRANSLATE
# ════════════════════════════════════════════════════════════════════════════

function ai-translate {
    <#
    .SYNOPSIS
    Translate text to any language. Auto-detects source language.
    No arguments = interactive multi-line session.
    .EXAMPLE
    ai-translate "Hello, how are you?" "French"
    ai-translate "Bonjour" "auto" "English"
    ai-translate               ← interactive mode
    #>
    param(
        [Parameter(Position=0)][string]$Text = "",
        [Parameter(Position=1)][string]$From = "auto",
        [Parameter(Position=2)][string]$To   = "English"
    )
    _SC-Track "ai-translate"
    if ([string]::IsNullOrWhiteSpace($Text)) {
        Write-Host ""; Write-Host "  [ ai-translate ] Interactive mode.  Type  exit  to quit." -ForegroundColor DarkCyan
        Write-Host "  Target language (default: English): " -NoNewline -ForegroundColor Yellow
        $tLang = (Read-Host).Trim()
        if ([string]::IsNullOrWhiteSpace($tLang)) { $tLang = "English" }
        while ($true) {
            Write-Host "  Text › " -NoNewline -ForegroundColor Yellow
            $inp = Read-Host
            if ([string]::IsNullOrWhiteSpace($inp)) { continue }
            if ($inp.Trim().ToLower() -eq "exit") { break }
            $result = _SC-Ask -Prompt "Translate to $tLang. Return ONLY the translated text, nothing else.`n`n$inp" `
                               -System "Return only the translation." -Silent
            Write-Host "  ➜  " -NoNewline -ForegroundColor Cyan
            Write-Host ($result.Trim()) -ForegroundColor Green; Write-Host ""
        }
        return
    }
    $fromClause = if ($From -ne "auto") { " from $From" } else { "" }
    Write-Host ""; Write-Host "  [ ai-translate ]$fromClause → $To" -ForegroundColor DarkCyan
    $prompt = if ($From -eq "auto") {
        "Detect language and translate to $To. Return ONLY the translated text.`n`n$Text"
    } else {
        "Translate from $From to $To. Return ONLY the translated text.`n`n$Text"
    }
    $result = _SC-Ask -Prompt $prompt -System "Return only the translation." -Silent
    if ([string]::IsNullOrWhiteSpace($result)) { return }
    Write-Host ""; Write-Host "  ── Original ─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  $Text" -ForegroundColor Gray
    Write-Host "  ── $To ─────────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  $($result.Trim())" -ForegroundColor Green
    Set-Clipboard -Value $result.Trim()
    Write-Host "  [✓] Copied to clipboard." -ForegroundColor DarkGray; Write-Host ""
}

# ════════════════════════════════════════════════════════════════════════════
#  FOCUS TIMER
# ════════════════════════════════════════════════════════════════════════════

function ai-timer {
    <#
    .SYNOPSIS
    Focus timer with a live progress bar. Default: 25 min Pomodoro.
    .EXAMPLE
    ai-timer               ← 25 min Pomodoro
    ai-timer 45 "Deep work"
    ai-timer 10 "Code review"
    #>
    param(
        [Parameter(Position=0)][int]   $Minutes = 25,
        [Parameter(Position=1)][string]$Label   = ""
    )
    if ($Minutes -le 0) {
        Write-Host "  [!] '$Minutes' is not a valid duration. Use a positive number." -ForegroundColor Yellow
        Write-Host "      Example: ai-timer 25  or  ai-timer 45 `"Deep work`"" -ForegroundColor DarkGray; return
    }
    _SC-Track "ai-timer"
    $totalSec = $Minutes * 60
    $tag      = if ($Label -ne "") { $Label } elseif ($Minutes -eq 25) { "Pomodoro" } else { "${Minutes}-min session" }
    $logFile  = Join-Path $env:TEMP "sc_timer_log.json"
    $start    = Get-Date

    Write-Host ""; Write-Host "  [ TIMER · $tag · ${Minutes} min ]" -ForegroundColor Cyan
    Write-Host "  Press Ctrl+C to cancel." -ForegroundColor DarkGray; Write-Host ""

    $elapsed = 0
    while ($elapsed -lt $totalSec) {
        $remaining = $totalSec - $elapsed
        $remMin    = [math]::Floor($remaining / 60); $remSec = $remaining % 60
        $pct       = [math]::Round(($elapsed / $totalSec) * 100)
        $barFill   = [math]::Round(($elapsed / $totalSec) * 30)
        $bar       = ("█" * $barFill) + ("░" * (30 - $barFill))
        $col       = if ($pct -lt 50) {"Green"} elseif ($pct -lt 80) {"Yellow"} else {"Red"}
        Write-Host "`r  [$bar]  ${remMin}m ${remSec}s  ($pct%)" -NoNewline -ForegroundColor $col
        Start-Sleep -Seconds 1; $elapsed++
    }
    Write-Host "`r  [██████████████████████████████]  Done!              " -ForegroundColor Green; Write-Host ""
    Write-Host "  ✅  $tag complete!" -ForegroundColor Green
    1..3 | ForEach-Object { [Console]::Beep(880, 300); Start-Sleep -Milliseconds 200 }

    # Log session
    $logs = _SC-LoadJson $logFile "array"
    $logs += [PSCustomObject]@{ date=$start.ToString("yyyy-MM-dd HH:mm"); label=$tag; minutes=$Minutes }
    _SC-SaveJson $logFile $logs

    $todayStr   = Get-Date -Format "yyyy-MM-dd"
    $todayTotal = ($logs | Where-Object { $_.date -like "$todayStr*" } | Measure-Object -Property minutes -Sum).Sum
    Write-Host "  🏆  Total focus today: ${todayTotal} min" -ForegroundColor Cyan; Write-Host ""
}

function ai-timer-log {
    <#
    .SYNOPSIS
    View your focus session history.
    .EXAMPLE
    ai-timer-log
    #>
    $f    = Join-Path $env:TEMP "sc_timer_log.json"
    $logs = _SC-LoadJson $f "array"
    if ($logs.Count -eq 0) {
        Write-Host ""; Write-Host "  [~] No focus sessions logged yet." -ForegroundColor Yellow
        Write-Host "      Start one: ai-timer" -ForegroundColor DarkGray; Write-Host ""; return
    }
    Write-Host ""; Write-Host "  ── Focus Log ($($logs.Count) sessions) ─────────────────────" -ForegroundColor Cyan
    $logs | Sort-Object date -Descending | Select-Object -First 15 | ForEach-Object {
        Write-Host "  ⏱ $($_.date)  " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($_.minutes) min  " -NoNewline -ForegroundColor Green
        Write-Host $_.label -ForegroundColor White
    }
    $total = ($logs | Measure-Object -Property minutes -Sum).Sum
    Write-Host ""; Write-Host "  🏆  All-time: $total min across $($logs.Count) sessions" -ForegroundColor Cyan; Write-Host ""
}

# ════════════════════════════════════════════════════════════════════════════
#  HISTORY
# ════════════════════════════════════════════════════════════════════════════

function ai-history {
    <#
    .SYNOPSIS
    Search your PowerShell command history by keyword.
    Add -AI for intent-based smart search.
    .EXAMPLE
    ai-history "git push"
    ai-history "docker run"
    ai-history "how to restart service" -AI
    #>
    param([Parameter(Mandatory,Position=0)][string]$Query, [switch]$AI)
    _SC-Track "ai-history"
    $psrlPath = try { (Get-PSReadLineOption).HistorySavePath } catch { "" }
    Write-Host ""; Write-Host "  [ ai-history ] Searching: '$Query'" -ForegroundColor DarkCyan
    if ($AI) {
        if (-not $psrlPath -or -not (Test-Path $psrlPath)) {
            Write-Host "  [!] PowerShell history file not found." -ForegroundColor Yellow
            Write-Host "      PSReadLine may not be installed. Try: Install-Module PSReadLine" -ForegroundColor DarkGray; return
        }
        $hist     = Get-Content $psrlPath -Tail 500 -Encoding UTF8
        $histText = $hist -join "`n"
        $result   = _SC-Ask -Prompt "From this PowerShell history, find up to 5 commands most relevant to: '$Query'`nReturn ONLY the matching command lines, one per line. No explanation." `
                             -System "Return only matching command lines. Nothing else." -Silent
        Write-Host ""; Write-Host "  ── AI Matches ─────────────────────────────────────" -ForegroundColor Cyan
        $result.Trim() -split "`n" | ForEach-Object { Write-Host "  › $($_.Trim())" -ForegroundColor Green }
        Write-Host ""
    } else {
        $matched = @()
        if ($psrlPath -and (Test-Path $psrlPath)) {
            $matched = @(Select-String -Path $psrlPath -Pattern ([regex]::Escape($Query)) -SimpleMatch -EA SilentlyContinue |
                         Select-Object -Last 20)
        }
        if ($matched.Count -eq 0) {
            # fallback to in-memory history
            $matched = @(Get-History | Where-Object { $_.CommandLine -match [regex]::Escape($Query) } | Select-Object -Last 20)
        }
        if ($matched.Count -eq 0) {
            Write-Host "  [~] No matches found for '$Query'." -ForegroundColor Yellow
            Write-Host "      Try a shorter keyword, or add  -AI  for intent-based search." -ForegroundColor DarkGray
            Write-Host "      Example: ai-history `"git`" -AI" -ForegroundColor Cyan; return
        }
        Write-Host "  ── $($matched.Count) match(es) ────────────────────────────" -ForegroundColor Cyan
        $matched | ForEach-Object {
            $line = if ($_.Line) { $_.Line } else { $_.CommandLine }
            Write-Host "  › $line" -ForegroundColor Green
        }
        Write-Host ""; Write-Host "  Tip: add  -AI  for smarter intent-based search." -ForegroundColor DarkCyan; Write-Host ""
    }
}

# ════════════════════════════════════════════════════════════════════════════
#  STANDUP & STATS
# ════════════════════════════════════════════════════════════════════════════

function ai-standup {
    <#
    .SYNOPSIS
    Auto-generate a daily standup from your Git commits and pending todos.
    .EXAMPLE
    ai-standup
    ai-standup "blocked on deployment approval"
    #>
    param([string]$Extra = "")
    _SC-Track "ai-standup"
    $cfg      = _SC-LoadConfig
    $role     = if (-not [string]::IsNullOrWhiteSpace($cfg.Role)) { $cfg.Role } else { "developer" }
    Write-Host ""; Write-Host "  [ ai-standup ] Generating standup..." -ForegroundColor DarkCyan

    $gitAuthor = git config user.name 2>$null
    $gitLog    = if ([string]::IsNullOrWhiteSpace($gitAuthor)) { "(git not configured — run: git config user.name `"Your Name`")" } else {
        $log = git log --oneline --since="yesterday" --author="$gitAuthor" 2>$null
        if ([string]::IsNullOrWhiteSpace($log)) { "(no commits since yesterday)" } else { $log }
    }
    $gitDiff  = if ([string]::IsNullOrWhiteSpace($gitAuthor)) { "" } else {
        _SC-Trim ((git diff --stat HEAD~1 2>$null) -join "`n") 3000
    }
    $todos    = _SC-LoadJson (Join-Path $env:TEMP "sc_todos.json") "array"
    $pending  = @($todos | Where-Object { -not $_.done })
    $todosRaw = if ($pending.Count -gt 0) { ($pending | ForEach-Object { "- $($_.task)" }) -join "`n" } else { "(none)" }

    _SC-Ask -Prompt @"
Write a professional daily standup for a $role. Use exactly 3 sections:
✅ YESTERDAY: (2-3 bullet points, past tense)
🔨 TODAY: (2-3 bullet points, future tense)
⚠️  BLOCKERS: (any blockers, or "None")

Context:
Git commits since yesterday: $gitLog
Changed files: $gitDiff
Pending todos: $todosRaw
Extra context: $Extra
"@ -System "Write a concise professional standup. No extra commentary." | Out-Null
}

function ai-stats {
    <#
    .SYNOPSIS
    View your usage dashboard — top commands, focus time, workspace summary, system info.
    .EXAMPLE
    ai-stats
    #>
    _SC-Track "ai-stats"
    $cfg = _SC-LoadConfig
    Write-Host ""; Write-Host "  [ USAGE DASHBOARD · $(Get-Date -Format 'dd MMM yyyy · HH:mm') ]" -ForegroundColor Cyan; Write-Host ""

    $usageData = _SC-LoadJson (Join-Path $env:TEMP "sc_usage.json") "hash"
    if ($usageData.Count -gt 0) {
        $total = ($usageData.Values | Measure-Object -Sum).Sum
        Write-Host "  ── Top Commands ─────────────────────────────────────" -ForegroundColor DarkCyan
        $usageData.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
            $bar = "█" * [math]::Min($_.Value, 25)
            $pct = if ($total -gt 0) { [math]::Round(($_.Value / $total) * 100) } else { 0 }
            Write-Host ("  {0,-18} {1,-26} {2,3}%  ×{3}" -f $_.Key, $bar, $pct, $_.Value) -ForegroundColor Gray
        }
        Write-Host "  Total commands run: $total" -ForegroundColor DarkGray; Write-Host ""
    }

    Write-Host "  ── Config ───────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  User     : $($cfg.UserName)" -ForegroundColor Gray
    Write-Host "  Role     : $($cfg.Role)" -ForegroundColor Gray
    Write-Host "  AI Mode  : $($cfg.AIMode)$(if ($cfg.AIMode -eq 'cloud') {" · $($cfg.APIProvider)"})" -ForegroundColor Gray
    Write-Host "  Model    : $(if ($cfg.AIMode -eq 'local'){$cfg.LocalModel}else{'Cloud API'})" -ForegroundColor Gray
    Write-Host "  City     : $(if ($cfg.City){ $cfg.City }else{ '(not set — run ai-setup)' })" -ForegroundColor Gray

    $timerLogs = _SC-LoadJson (Join-Path $env:TEMP "sc_timer_log.json") "array"
    if ($timerLogs.Count -gt 0) {
        $totalMin = ($timerLogs | Measure-Object -Property minutes -Sum).Sum
        $todayMin = ($timerLogs | Where-Object { $_.date -like "$(Get-Date -Format 'yyyy-MM-dd')*" } |
                    Measure-Object -Property minutes -Sum).Sum
        Write-Host ""; Write-Host "  ── Focus Time ────────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host "  Today    : $todayMin min" -ForegroundColor Green
        Write-Host "  All-time : $totalMin min across $($timerLogs.Count) sessions" -ForegroundColor Gray
    }

    $todos     = _SC-LoadJson (Join-Path $env:TEMP "sc_todos.json") "array"
    $notes     = _SC-LoadJson (Join-Path $env:TEMP "sc_notes.json") "array"
    $snippets  = _SC-LoadJson (Join-Path $env:TEMP "sc_snippets.json") "hash"
    $pending   = @($todos | Where-Object { -not $_.done }).Count
    Write-Host ""; Write-Host "  ── Workspace ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  Todos    : $pending pending" -ForegroundColor $(if($pending -gt 0){"Yellow"}else{"DarkGray"})
    Write-Host "  Notes    : $($notes.Count) saved" -ForegroundColor DarkGray
    Write-Host "  Snippets : $($snippets.Count) saved" -ForegroundColor DarkGray

    $osInfo   = Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue
    $freeRam  = if ($osInfo) { [math]::Round($osInfo.FreePhysicalMemory / 1MB, 1) } else { 0 }
    $totalRam = if ($osInfo) { [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 1) } else { 0 }
    $usedPct  = if ($totalRam -gt 0) { [math]::Round((1 - ($freeRam / $totalRam)) * 100) } else { 0 }
    $barFill  = [math]::Round(($usedPct / 100) * 24)
    $ramBar   = ("█" * $barFill) + ("░" * (24 - $barFill))
    $ramColor = if ($usedPct -gt 88) {"Red"} elseif ($usedPct -gt 70) {"Yellow"} else {"Green"}
    Write-Host ""; Write-Host "  ── System ────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  RAM      : |$ramBar|  $usedPct% used  ·  ${freeRam} GB free" -ForegroundColor $ramColor
    if ($osInfo) {
        $uptime = (Get-Date) - $osInfo.LastBootUpTime
        Write-Host "  Uptime   : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ════════════════════════════════════════════════════════════════════════════
#  MODEL & SYSTEM MANAGEMENT
# ════════════════════════════════════════════════════════════════════════════

function ai-model {
    <#
    .SYNOPSIS
    List available Ollama models or switch to a specific one.
    .EXAMPLE
    ai-model               ← list all installed models
    ai-model mistral       ← switch to mistral
    ai-model gemma2:2b     ← switch to the lightweight model
    #>
    param([string]$Name = "")
    $cfg = _SC-LoadConfig
    if ($cfg.AIMode -eq "cloud") {
        Write-Host ""; Write-Host "  Cloud mode is active: $($cfg.APIProvider)" -ForegroundColor DarkCyan
        Write-Host "  ai-model is for local Ollama only." -ForegroundColor DarkGray
        Write-Host "  To switch AI backend: ai-setup" -ForegroundColor Cyan; return
    }
    if ($Name -eq "") {
        Write-Host ""; Write-Host "  [ ai-model ] Installed Ollama models:" -ForegroundColor DarkCyan
        if (-not (_SC-OllamaCheck)) { return }
        try {
            $tags = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 5 -EA Stop
            if ($tags.models.Count -eq 0) {
                Write-Host "  [~] No models installed." -ForegroundColor Yellow
                Write-Host "      Install one:  ollama pull mistral    (4 GB RAM · best for code)" -ForegroundColor Cyan
                Write-Host "                    ollama pull gemma2:2b  (2 GB RAM · lightest)" -ForegroundColor Cyan; return
            }
            $tags.models | ForEach-Object {
                $active = if ($_.name -eq $Global:SC_MODEL) { " ◄ ACTIVE" } else { "" }
                $sizeGB = [math]::Round($_.size / 1GB, 1)
                Write-Host "  • $($_.name.PadRight(28)) $sizeGB GB$active" -ForegroundColor $(if($active){"Green"}else{"Gray"})
            }
            Write-Host ""; Write-Host "  Switch: ai-model <name>   |   Load into VRAM: ai-run" -ForegroundColor DarkCyan; Write-Host ""
        } catch {
            Write-Host "  [✗] Could not list models: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        $available = _SC-OllamaListModels
        $match     = $available | Where-Object { $_ -like "*$Name*" } | Select-Object -First 1
        if (-not $match) {
            # Check for exact match first, then fuzzy
            if ($available -contains $Name) { $match = $Name }
        }
        if (-not $match -and $available.Count -gt 0) {
            Write-Host "  [!] No model matching '$Name' is installed." -ForegroundColor Yellow
            Write-Host "      Installed models: $($available -join ', ')" -ForegroundColor DarkGray
            Write-Host "      Pull it first: ollama pull $Name" -ForegroundColor Cyan; return
        }
        $target          = if ($match) { $match } else { $Name }
        $Global:SC_MODEL = $target
        $cfg.LocalModel  = $target
        _SC-SaveConfig $cfg | Out-Null
        Write-Host "  [✓] Model set to: $target (saved for future sessions)" -ForegroundColor Green
        Write-Host "      Run  ai-run  to load it into VRAM now." -ForegroundColor DarkGray
    }
}

function ai-stop {
    <#
    .SYNOPSIS
    Flush VRAM and optionally free RAM.
    [Y] = Stop everything (server + inference + RAM scrub)
    [I] = Inference only (VRAM flush, server stays running)
    [S] = Skip
    .EXAMPLE
    ai-stop
    #>
    _SC-Track "ai-stop"
    $cfg = _SC-LoadConfig
    if ($cfg.AIMode -eq "cloud") {
        Write-Host ""; Write-Host "  [~] Cloud mode is active — nothing local to flush." -ForegroundColor DarkCyan; return
    }
    Write-Host ""; Write-Host "  [ ai-stop · MEMORY FLUSH ]" -ForegroundColor Red
    $freeRAM = _SC-GetFreeRAM_GB
    if ($freeRAM -ne 999) { Write-Host "  Current free RAM: ${freeRAM} GB" -ForegroundColor Gray }
    Write-Host ""
    Write-Host "  [Y] Force Stop All   [I] Inference Only   [S] Skip" -ForegroundColor Yellow
    Write-Host "      Y = kills server + model (frees most memory)" -ForegroundColor DarkGray
    Write-Host "      I = unloads model only  (server stays alive)" -ForegroundColor DarkGray
    $choice = (Read-Host "  Choice").Trim().ToUpper()
    if ($choice -eq "S" -or $choice -eq "") { Write-Host "  [Skipped]" -ForegroundColor DarkGray; return }
    if ($choice -notin @("Y","I")) {
        Write-Host "  [!] '$choice' is not valid. Options: Y, I, or S." -ForegroundColor Yellow; return
    }
    $before = _SC-GetFreeRAM_GB
    Write-Host ""

    # Both I and Y flush active inference
    $infer = Get-Process "ollama_llama_server", "llama-server" -EA SilentlyContinue
    if ($infer) {
        $infer | Stop-Process -Force -EA SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "  [✓] Model unloaded from VRAM." -ForegroundColor Green
    } else {
        Write-Host "  [~] No active inference process found." -ForegroundColor DarkGray
    }

    if ($choice -eq "Y") {
        Get-Process "ollama" -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
        Write-Host "  [✓] Ollama server stopped." -ForegroundColor Green

        # Kill background Python processes (headless only)
        $pyProcs = Get-Process "python" -EA SilentlyContinue | Where-Object { $_.MainWindowTitle -eq "" }
        if ($pyProcs) {
            $pyProcs | Stop-Process -Force -EA SilentlyContinue
            Write-Host "  [✓] Background Python processes cleared." -ForegroundColor Green
        }

        # .NET GC pass
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        # Working set trim (shrinks PowerShell's own RAM footprint)
        try {
            if (-not ([System.Management.Automation.PSTypeName]'MemUtil.WSFlush').Type) {
                Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern bool SetProcessWorkingSetSize(IntPtr h, IntPtr mn, IntPtr mx);' `
                         -Name WSFlush -Namespace MemUtil -EA Stop
            }
            [MemUtil.WSFlush]::SetProcessWorkingSetSize(
                [System.Diagnostics.Process]::GetCurrentProcess().Handle,
                [IntPtr](-1), [IntPtr](-1)) | Out-Null
            Write-Host "  [✓] System working set trimmed." -ForegroundColor Green
        } catch { }
    }

    $after = _SC-GetFreeRAM_GB
    if ($before -ne 999 -and $after -ne 999) {
        $freed = [math]::Round($after - $before, 1)
        Write-Host ""; Write-Host "  RAM: ${before} GB → ${after} GB  (freed: +${freed} GB)" -ForegroundColor $(if($freed -gt 0){"Green"}else{"Gray"})
    }
    Write-Host "  Next: run  ai-run  to restart the server and pick a model." -ForegroundColor DarkCyan; Write-Host ""
}

function ai-run {
    <#
    .SYNOPSIS
    Start Ollama, pick a model from a menu, and load it into VRAM.
    .EXAMPLE
    ai-run
    #>
    $cfg = _SC-LoadConfig
    if ($cfg.AIMode -eq "cloud") {
        Write-Host ""; Write-Host "  Cloud mode is active — no local server needed." -ForegroundColor DarkCyan
        Write-Host "  To switch to local AI: ai-setup" -ForegroundColor DarkGray; return
    }
    Write-Host ""; Write-Host "  [ ai-run · STARTUP ]" -ForegroundColor Cyan

    # Start Ollama if not already running
    if (Get-Process "ollama" -EA SilentlyContinue) {
        Write-Host "  [✓] Ollama is already running." -ForegroundColor Green
    } else {
        Write-Host "  [~] Starting Ollama..." -ForegroundColor Yellow
        $env:CUDA_VISIBLE_DEVICES = "0"
        try {
            Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden -EA Stop
            Start-Sleep -Seconds 3
        } catch {
            Write-Host "  [✗] Could not start Ollama: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "      Is Ollama installed? Download it from: https://ollama.com" -ForegroundColor DarkGray; return
        }
        if (-not (Get-Process "ollama" -EA SilentlyContinue)) {
            Write-Host "  [✗] Ollama process started but died immediately." -ForegroundColor Red
            Write-Host "      Try running manually in a new terminal: ollama serve" -ForegroundColor DarkGray; return
        }
        Write-Host "  [✓] Ollama started in background." -ForegroundColor Green
    }

    _SC-WarnLowRAM
    Write-Host ""; Write-Host "  [ Available Models ]" -ForegroundColor DarkCyan
    $rawModels = ollama list 2>&1
    $models    = @()
    foreach ($line in $rawModels) {
        if ($line -match "^NAME" -or [string]::IsNullOrWhiteSpace($line)) { continue }
        $modelName = ($line -split '\s+')[0]
        if ($modelName) { $models += $modelName }
    }
    if ($models.Count -eq 0) {
        Write-Host "  [!] No models installed." -ForegroundColor Yellow
        Write-Host "      Install one first:" -ForegroundColor DarkGray
        Write-Host "        ollama pull mistral     ← best for code  (~4 GB RAM)" -ForegroundColor Cyan
        Write-Host "        ollama pull gemma2:2b   ← lightest option (~2 GB RAM)" -ForegroundColor Cyan
        Write-Host "        ollama pull moondream   ← adds image analysis" -ForegroundColor Cyan
        Write-Host "      Then run  ai-run  again." -ForegroundColor DarkGray
        return
    }
    for ($i = 0; $i -lt $models.Count; $i++) {
        $active = if ($models[$i] -eq $Global:SC_MODEL) { " ◄ active" } else { "" }
        Write-Host "  [$($i+1)] $($models[$i])$active" -ForegroundColor $(if($active){"Green"}else{"Yellow"})
    }
    Write-Host "  [S] Skip — keep current: $Global:SC_MODEL" -ForegroundColor DarkGray; Write-Host ""
    $choice = (Read-Host "  Select Model").Trim().ToUpper()
    if ($choice -eq "S" -or $choice -eq "") {
        Write-Host "  [~] Keeping: $Global:SC_MODEL" -ForegroundColor DarkGray; Write-Host ""; return
    }
    $index = 0
    if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $models.Count) {
        Write-Host "  [!] '$choice' is not a valid selection (1–$($models.Count) or S)." -ForegroundColor Yellow
        Write-Host "      Run  ai-run  again to retry." -ForegroundColor DarkGray; return
    }
    $selected = $models[$index - 1]
    if ($selected -eq $Global:SC_MODEL) {
        Write-Host ""; Write-Host "  [✓] '$selected' is already active." -ForegroundColor Green; Write-Host ""; return
    }
    _SC-FlushVRAM
    Write-Host ""; Write-Host "  [>] Loading '$selected' into VRAM..." -ForegroundColor Cyan
    try {
        $warmBody = @{ model=$selected; prompt="ready"; stream=$false } | ConvertTo-Json -Compress
        $null = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method POST `
                -Body $warmBody -ContentType "application/json" -TimeoutSec 120 -EA Stop
        $Global:SC_MODEL = $selected
        $cfg.LocalModel  = $selected
        _SC-SaveConfig $cfg | Out-Null
        Write-Host "  [✓] '$selected' is loaded and ready." -ForegroundColor Green
    } catch {
        Write-Host "  [✗] Failed to load '$selected'." -ForegroundColor Red
        Write-Host "  ── Possible causes ─────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "   • Not enough RAM or VRAM for this model" -ForegroundColor Yellow
        Write-Host "   • Run  ai-stop  → then try a lighter model (gemma2:2b = 2 GB)" -ForegroundColor Yellow
        Write-Host "   • Or switch to Cloud AI:  ai-setup  →  option 2 or 3" -ForegroundColor Cyan
    }
    Write-Host ""
}

# Convenience alias — kept for muscle memory, points to ai-run
function ollama-start { ai-run }
Set-Alias osve ollama-start

# ════════════════════════════════════════════════════════════════════════════
#  SELF-TEST
# ════════════════════════════════════════════════════════════════════════════

function ai-self-test {
    <#
    .SYNOPSIS
    Run a full system diagnostic. Use this after setup on a new machine.
    .EXAMPLE
    ai-self-test
    #>
    Write-Host ""; Write-Host "  [ AI ARSENAL · SYSTEM DIAGNOSTICS ]" -ForegroundColor Magenta
    Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkGray

    $pass  = 0
    $total = 7

    function _Assert {
        param([string]$Name, [bool]$Cond, [string]$Fail, [string]$Fix = "")
        if ($Cond) {
            Write-Host "  [✓] $Name" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  [✗] $Name" -ForegroundColor Red
            Write-Host "      Problem: $Fail" -ForegroundColor DarkGray
            if ($Fix) { Write-Host "      Fix:     $Fix" -ForegroundColor Yellow }
            return $false
        }
    }

    $cfg = _SC-LoadConfig

    # 1. Config file
    if (_Assert "Config file present" (Test-Path $Global:SC_CONFIG_FILE) `
        "Config file not found at $($Global:SC_CONFIG_FILE)" `
        "Run: ai-setup") { $pass++ }

    # 2. Name
    if (_Assert "User name configured" (-not [string]::IsNullOrWhiteSpace($cfg.UserName)) `
        "Name is blank." "Run: ai-setup → step 1") { $pass++ }

    # 3. Role
    if (_Assert "Role configured" (-not [string]::IsNullOrWhiteSpace($cfg.Role)) `
        "Role is blank." "Run: ai-setup → step 2") { $pass++ }

    # 4. AI backend reachable
    $backendOk = $false
    if ($cfg.AIMode -eq "cloud") {
        $backendOk = -not [string]::IsNullOrWhiteSpace($cfg.APIKey)
        if (_Assert "Cloud API key present" $backendOk `
            "API key is empty — cloud AI will not work." `
            "Run: ai-setup → step 3 → enter your key") { $pass++ }
    } else {
        $backendOk = _SC-OllamaReachable
        if (_Assert "Ollama is reachable" $backendOk `
            "Ollama is not running." `
            "Run: ai-run  OR  open a terminal and type: ollama serve") { $pass++ }
    }

    # 5. File read engine
    $testFile   = Join-Path $env:TEMP "sc_selftest_dummy.txt"
    "FileEngineOK" | Set-Content $testFile -Encoding UTF8 -Force
    $readResult = _SC-ReadFile $testFile
    Remove-Item $testFile -EA SilentlyContinue
    if (_Assert "File read/write engine" ($readResult.Trim() -eq "FileEngineOK") `
        "Could not write and read a test file from $env:TEMP" `
        "Check that $env:TEMP is writable and not full.") { $pass++ }

    # 6. Snippet JSON round-trip  (uses a unique key to avoid stale-key false-fail)
    $testKey  = "self-test-$(Get-Date -Format 'HHmmss')"
    $jsonOk   = $false
    try {
        ai-snippet save $testKey "ok-$testKey" 2>&1 | Out-Null
        $snips  = _SC-LoadJson (Join-Path $env:TEMP "sc_snippets.json") "hash"
        $jsonOk = $snips.ContainsKey($testKey) -and $snips[$testKey] -like "ok-*"
        ai-snippet delete $testKey 2>&1 | Out-Null
    } catch {}
    if (_Assert "JSON storage round-trip" $jsonOk `
        "Snippet save/read failed." `
        "Check that $env:TEMP is writable.") { $pass++ }

    # 7. Live inference
    $inferOk = $false
    if ($backendOk) {
        Write-Host "  [ ] Live AI inference..." -NoNewline -ForegroundColor DarkGray
        $resp    = _SC-Ask -Prompt "Reply with exactly the word: ARSENAL" `
                            -System "Return only the single word ARSENAL. Nothing else." -Silent
        $inferOk = ($resp -match "ARSENAL")
        Write-Host "`r" -NoNewline
        if (_Assert "Live AI inference" $inferOk `
            "Model did not return expected response." `
            "Try: ai-run (local)  OR  ai-setup to check your API key (cloud)") { $pass++ }
    } else {
        Write-Host "  [~] Live inference skipped — AI backend not reachable." -ForegroundColor DarkGray
    }

    Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkGray
    if ($pass -eq $total) {
        Write-Host "  [ ✅  ALL $total/$total CHECKS PASSED — System is ready ]" -ForegroundColor Green
    } else {
        $failed = $total - $pass
        Write-Host "  [ ⚠️   $failed CHECK(S) FAILED — $pass/$total passed ]" -ForegroundColor Red
        Write-Host "  Follow the  Fix:  lines above to resolve each issue." -ForegroundColor Yellow
        Write-Host "  Then run  ai-self-test  again to verify." -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ════════════════════════════════════════════════════════════════════════════
#  HELP BANNER
# ════════════════════════════════════════════════════════════════════════════

function ai-quick { ai-help -Mode quick }

function ai-help {
    param([string]$Mode = "")
    $Quick = ($Mode -eq "quick")
    Clear-Host

    $cfg       = _SC-LoadConfig
    $userName  = if (-not [string]::IsNullOrWhiteSpace($cfg.UserName)) { $cfg.UserName } else { "User" }
    $aiTag     = if ($cfg.AIMode -eq "cloud") { "Cloud › $($cfg.APIProvider)" } else { "Local › $($cfg.LocalModel)" }
    $animStyle = if ($Quick) { "instant" } else { $cfg.AnimStyle }

    # ── ASCII FONT ENGINE ─────────────────────────────────────────────────
    $font = @{
        'A'=@(' █████ ','██   ██','███████','██   ██','██   ██')
        'B'=@('██████ ','██   ██','██████ ','██   ██','██████ ')
        'C'=@(' ██████','██     ','██     ','██     ',' ██████')
        'D'=@('██████ ','██   ██','██   ██','██   ██','██████ ')
        'E'=@('███████','██     ','█████  ','██     ','███████')
        'F'=@('███████','██     ','█████  ','██     ','██     ')
        'G'=@(' ██████','██     ','██  ███','██   ██',' ██████')
        'H'=@('██   ██','██   ██','███████','██   ██','██   ██')
        'I'=@('███',' ██',' ██',' ██','███')
        'J'=@('      ██','      ██','      ██','██    ██',' ██████ ')
        'K'=@('██   ██','██  ██ ','█████  ','██  ██ ','██   ██')
        'L'=@('██     ','██     ','██     ','██     ','███████')
        'M'=@('███   ███','████ ████','██ ███ ██','██     ██','██     ██')
        'N'=@('███    ██','████   ██','██ ██  ██','██  ██ ██','██   ████')
        'O'=@(' ██████ ','██    ██','██    ██','██    ██',' ██████ ')
        'P'=@('██████ ','██   ██','██████ ','██     ','██     ')
        'Q'=@(' ██████ ','██    ██','██    ██','██  █ ██',' ██████ ██')
        'R'=@('██████ ','██   ██','██████ ','██  ██ ','██   ██')
        'S'=@(' ██████','██     ',' █████ ','     ██','██████ ')
        'T'=@('███████','  ██   ','  ██   ','  ██   ','  ██   ')
        'U'=@('██    ██','██    ██','██    ██','██    ██',' ██████ ')
        'V'=@('██    ██','██    ██','██    ██',' ██  ██ ','  ████  ')
        'W'=@('██      ██','██      ██','██  ██  ██','██  ██  ██',' ████████ ')
        'X'=@('██    ██',' ██  ██ ','  ████  ',' ██  ██ ','██    ██')
        'Y'=@('██    ██',' ██  ██ ','  ████  ','   ██   ','   ██   ')
        'Z'=@('███████','     ██','   ██  ',' ██    ','███████')
        ' '=@('   ','   ','   ','   ','   ')
    }

    $cleanName = ($userName.ToUpper() -replace '[^A-Z ]', '')
    $nameLines = @("","","","","")
    foreach ($char in $cleanName.ToCharArray()) {
        $letter = $font[$char.ToString()]
        if ($null -eq $letter) { $letter = $font[' '] }
        for ($i = 0; $i -lt 5; $i++) { $nameLines[$i] += $letter[$i] + " " }
    }
    $artBody = ""
    foreach ($line in $nameLines) {
        $pad      = [math]::Max(0, [math]::Floor((75 - $line.Length) / 2))
        $artBody += (" " * $pad) + $line + "`n"
    }
    $art = @"
  ════════════════════════════════════════════════════════════════════════════

$artBody
                     A  R  S  E  N  A  L   v $($Global:SC_VERSION)
  ════════════════════════════════════════════════════════════════════════════
"@

    if ($animStyle -eq "glitch") {
        for ($i = 0; $i -lt 3; $i++) {
            $label = @("CORE","MODELS","ARSENAL")[$i]
            Write-Host -NoNewline "  $($label.PadRight(10)) ["
            for ($j = 0; $j -lt 28; $j++) { Write-Host "█" -NoNewline -ForegroundColor Green; Start-Sleep -Milliseconds 6 }
            Write-Host "]  " -NoNewline; Write-Host "OK" -ForegroundColor Green
        }
        Start-Sleep -Milliseconds 60; Clear-Host; Start-Sleep -Milliseconds 40
        $lines  = $art -split "`n"
        foreach ($l in $lines) { Write-Host "" }
        $startY = [System.Console]::CursorTop - $lines.Count
        if ($startY -lt 0) { $startY = 0 }
        $sw     = [System.Diagnostics.Stopwatch]::StartNew()
        $chars  = [char[]]"01XYZ#@%&*ABCDEFGHIJKLMNOPQRSTUVWXYZ▓▒░"
        while ($sw.ElapsedMilliseconds -lt 3200) {
            [System.Console]::SetCursorPosition(0, $startY)
            $progress = $sw.ElapsedMilliseconds / 3200.0
            $glitch   = 90 - (90 * $progress)
            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line)) { Write-Host ""; continue }
                $arr = $line.ToCharArray()
                for ($i = 0; $i -lt $arr.Length; $i++) {
                    if ($arr[$i] -ne ' ' -and (Get-Random -Max 100) -lt $glitch) {
                        $arr[$i] = $chars | Get-Random
                    }
                }
                Write-Host (-join $arr) -ForegroundColor Green
            }
            Start-Sleep -Milliseconds 55
        }
        [System.Console]::SetCursorPosition(0, $startY)
        foreach ($line in $lines) { Write-Host $line -ForegroundColor Green }
    } elseif ($animStyle -eq "typewriter") {
        $art -split "`n" | ForEach-Object {
            $_.ToCharArray() | ForEach-Object { Write-Host $_ -NoNewline -ForegroundColor Green; Start-Sleep -Milliseconds 1 }
            Write-Host ""
        }
    } else {
        Write-Host $art -ForegroundColor Green
    }

    Write-Host ""; Write-Host "  [ ARSENAL ONLINE · $aiTag ]" -ForegroundColor DarkCyan
    Write-Host "  [ $userName — Execute. Every. Day. ]" -ForegroundColor Cyan

    # ── Helper closures ────────────────────────────────────────────────────
    function _S { param([string]$L,[string]$C="DarkCyan") Write-Host ""; Write-Host "  [ $L ]" -ForegroundColor $C; Write-Host "" }
    function _D { Write-Host "  ─────────────────────────────────────────────────────────" -ForegroundColor DarkGray }
    function _C {
        param([string]$Cmd,[string]$Desc)
        Write-Host "  ➜ " -NoNewline -ForegroundColor Cyan
        Write-Host "$($Cmd.PadRight(28)) " -NoNewline -ForegroundColor White
        Write-Host $Desc -ForegroundColor Gray
    }
    function _E {
        param([string]$Ex,[string]$After="")
        Write-Host "      Ex: " -NoNewline -ForegroundColor DarkGreen
        Write-Host $Ex -ForegroundColor Green
        if ($After) { Write-Host "      ↳  " -NoNewline -ForegroundColor DarkYellow; Write-Host $After -ForegroundColor Yellow }
    }

    _S "⚙  SETUP & SYSTEM"
    _C "ai-setup"              "First-time wizard — name, AI backend, key, city."
    _E "ai-setup"              "Run anytime to change any setting."
    _C "ai-self-test"          "Full system diagnostic — verify everything works."
    _E "ai-self-test"          "Fix the red items, then run it again."
    _C "ai-run"                "Start Ollama and pick a model from a menu."
    _E "ai-run"                "Use after ai-stop or on a fresh terminal."
    _C "ai-stop"               "Flush VRAM / free RAM when AI is slow or crashing."
    _E "ai-stop"               "[Y] = kill everything  [I] = unload model only."
    _C "ai-model [name]"       "List or switch local Ollama models."
    _E "ai-model gemma2:2b"    "Then run ai-run to load it into VRAM."
    _C "ai-stats"              "Usage dashboard — commands, focus time, workspace."
    _D

    _S "⚡ QUICK AI & CHAT"
    _C "ai `"question`""        "One-shot AI question — the fastest command."
    _E "ai `"what is a deadlock?`""
    _C "ai-ask `"question`""    "Fast factual answer — handles time/date locally."
    _E "ai-ask `"what time is it?`""
    _C "ai-chat"               "Multi-turn conversation with session memory."
    _E "ai-chat"               "Type /file <path> inside to inject a file."
    _C "ai-cmd `"task`""        "Describe a task → get a PowerShell command."
    _E "ai-cmd `"list .java files modified today`"" "[R] to run it immediately."
    _C "ai-clip [`"question`"]"  "Analyse text currently in your clipboard."
    _E "ai-clip `"find bugs in this code`""
    _D

    _S "📂 FILES & FOLDERS"
    _C "ai-sum `"path`""        "Summarise a PDF, Word doc, or text file."
    _E "ai-sum `"report.pdf`""
    _C "ai-file `"file`" `"q`""   "Ask a question about any file."
    _E "ai-file `"config.json`" `"explain each setting`""
    _C "ai-folder `"path`""     "Batch-analyse all code files in a folder."
    _E "ai-folder `"./src`""
    _C "ai-search `"query`""    "Search files by name. Add -Content for text search."
    _E "ai-search `"login`" -Content"
    _C "ai-copy `"path`""       "Copy a file's content to clipboard."
    _E "ai-copy `"Main.java`""  "Then run ai-clip to ask questions about it."
    _C "ai-fix `"file`""        "AI auto-fixes all bugs. Original is backed up."
    _E "ai-fix `"script.py`""   "[Y] to save the fixed version."
    _D

    _S "🌐 MEDIA & WEB"
    _C "ai-img `"path`" [`"q`"]"  "Describe or analyse an image / PDF page."
    _E "ai-img `"error.png`" `"why did this fail?`""
    _C "ai-ocr `"path`""        "Extract text from an image or scanned PDF."
    _E "ai-ocr `"scan.pdf`""
    _C "ai-web `"url`" [`"q`"]"   "Fetch a webpage and ask a question about it."
    _E "ai-web `"docs.spring.io`" `"summarize Spring Boot setup`""
    _C "ai-weather"             "Current weather + 3-day forecast + AQI."
    _E "ai-weather"             "Set your city first: ai-setup → step 4."
    _C "ai-open `"target`""     "Open an app, folder, or website by name."
    _E "ai-open brave"          "Also works: ai-open youtube · ai-open vscode"
    _D

    _S "🛠️  CODE QUALITY & GIT"
    _C "ai-qa `"feature`""      "Generate Cucumber + TestNG test automation."
    _E "ai-qa `"user login with valid credentials`""
    _C "ai-debug `"file`""      "Find bugs with line numbers and fix snippets."
    _E "ai-debug `"App.java`""  "Then run ai-fix to apply them automatically."
    _C "ai-test `"file`""       "Generate unit tests (happy path + edge cases)."
    _E "ai-test `"Utils.java`""
    _C "ai-review `"file`""     "Senior-level code review (SOLID, security, etc)."
    _E "ai-review `"Api.java`""
    _C "ai-diff"                "AI review of staged + unstaged Git changes."
    _E "ai-diff"                "Then run ai-commit to generate a commit message."
    _C "ai-commit"              "Generate Conventional Commit messages from staged diff."
    _E "ai-commit"              "Stage files first: git add ."
    _C "ai-git-push"            "Stage + commit + push — all in one command."
    _E "ai-git-push"            "[Y] confirm · [E] edit message · [S] skip."
    _D

    _S "🎯 INTERVIEW PREP" "Magenta"
    _C "ai-visual `"topic`""    "ASCII flow diagram. Add -Fancy for box diagram."
    _E "ai-visual `"OAuth2 flow`" -Fancy"
    _C "ai-mindmap `"topic`""   "Study guide + ASCII mind map tree."
    _E "ai-mindmap `"Java Collections`""
    _C "ai-flashcard `"topic`"" "Spaced-repetition flashcard with scoring."
    _E "ai-flashcard `"SQL`""   "Answer out loud — get graded CORRECT/PARTIAL/WRONG."
    _C "ai-explain `"input`""   "Line-by-line breakdown + gotcha + interview tip."
    _E "ai-explain `"HashMap internals`""
    _C "ai-cheatsheet `"topic`"" "Compact emoji cheatsheet for quick revision."
    _E "ai-cheatsheet `"git commands`""
    _C "ai-interview `"topic`"" "Single mock question with score and model answer."
    _E "ai-interview `"Java`""  "Answer naturally to get a score out of 10."
    _C "ai-mock `"role`""       "Full 5-question mock session with final verdict."
    _E "ai-mock `"Java SDET`""  "Takes ~10 min · gives READY / NEEDS PREP verdict."
    _C "ai-jd [`"path`"]"        "Analyse a Job Description for gaps + prep tips."
    _E "ai-jd `"jd.txt`""
    _D

    _S "📝 WORKSPACE & PRODUCTIVITY" "DarkYellow"
    _C "ai-note `"text`""       "Save a persistent note."
    _E "ai-note `"review ArrayDeque before interview`""
    _C "ai-notes"               "List all saved notes."
    _C "ai-note-clear"          "Delete all notes permanently (asks for confirmation)."
    _C "ai-todo `"task`""       "Add a task to your to-do list."
    _E "ai-todo `"fix Selenium grid config`""
    _C "ai-todos"               "View all todos (pending and completed)."
    _C "ai-done <id>"           "Mark a todo complete by ID."
    _E "ai-done 3"
    _C "ai-snippet save/get/list/delete" "Manage reusable code snippets."
    _E "ai-snippet save `"db-url`" `"jdbc:...`"" "ai-snippet get `"db-url`" to retrieve + copy."
    _C "ai-translate `"text`" `"Lang`"" "Translate text. No args = interactive mode."
    _E "ai-translate `"Hello!`" `"French`""
    _C "ai-timer [min] [`"label`"]" "Focus timer with live bar + beep when done."
    _E "ai-timer 45 `"Deep Work`"" "ai-timer-log to view history."
    _C "ai-history `"query`" [-AI]" "Search PowerShell history. -AI = smart search."
    _E "ai-history `"git push`" -AI"
    _C "ai-standup [`"extra`"]"  "Auto-generate standup from Git + todos."
    _E "ai-standup `"blocked by QA`"" "Copy and paste into Slack / Teams."

    # ── System snapshot ────────────────────────────────────────────────────
    _D
    $osInfo   = Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue
    $freeRam  = if ($osInfo) { [math]::Round($osInfo.FreePhysicalMemory / 1MB, 1) } else { 0 }
    $totalRam = if ($osInfo) { [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 1) } else { 0 }
    $usedPct  = if ($totalRam -gt 0) { [math]::Round((1 - ($freeRam / $totalRam)) * 100) } else { 0 }
    $barFill  = [math]::Round(($usedPct / 100) * 24)
    $ramBar   = ("█" * $barFill) + ("░" * (24 - $barFill))
    $ramColor = if ($usedPct -gt 88) {"Red"} elseif ($usedPct -gt 70) {"Yellow"} else {"Green"}
    Write-Host "  💻  SYSTEM" -ForegroundColor Yellow
    Write-Host "  🧠  RAM    : |$ramBar|  $usedPct% used  ·  ${freeRam} GB free" -ForegroundColor $ramColor
    if ($osInfo) {
        $uptime = (Get-Date) - $osInfo.LastBootUpTime
        Write-Host "  ⏱   Uptime : $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor DarkGray
    }

    # Session log
    $slogFile = Join-Path $env:TEMP "sc_session.json"
    $last     = "First session"
    try {
        if (Test-Path $slogFile) { $last = (Get-Content $slogFile -Raw | ConvertFrom-Json).last }
        @{ last = (Get-Date -Format "yyyy-MM-dd HH:mm") } | ConvertTo-Json -Compress |
            Set-Content $slogFile -Encoding UTF8
    } catch {}
    Write-Host ""; Write-Host "  Last opened : $last" -ForegroundColor DarkGray
    Write-Host "  Now         : $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
    Write-Host ""
}