# Installs the desktop-side watchdog that notices when Home Assistant stops answering.
#
# Why this exists: on 2026-08-14 the kernel OOM-killed HA Core at 18:11 and nothing
# restarted it. It sat dead for 19 hours before anyone noticed, with every automation
# in the house offline the whole time. HA cannot alert you that HA is down, so the
# check has to live off the Pi. This is that check.
#
# It registers a per-user scheduled task that polls https://192.168.0.100:8123 every
# 5 minutes and raises a desktop notification once HA has missed two checks in a row.
# It nags hourly while HA stays down and says so once it comes back. Quiet otherwise.
#
# Same conventions as install-heartbeat.ps1: conhost --headless so nothing flashes,
# curl -k because HA is reached by LAN IP while its certificate names the DuckDNS host,
# no admin rights needed, safe to re-run (it replaces the existing task).
#
# Limitation worth knowing: like the heartbeat task, this runs only while you are
# logged on. It will not catch an outage that starts and ends while the PC is off.
#
# Remove with: Unregister-ScheduledTask -TaskName 'HA Watchdog' -Confirm:$false

# ---- config ----
$taskName    = 'HA Watchdog'
$haUrl       = 'https://192.168.0.100:8123/'
$installDir  = Join-Path $env:LOCALAPPDATA 'HAWatchdog'
$scriptPath  = Join-Path $installDir 'ha-watchdog.ps1'
$pollMinutes = 5      # how often to check
$failsToWarn = 2      # consecutive misses before the first alert (2 x 5min = 10min)
$nagEvery    = 12     # while still down, re-alert every 12 checks (1 hour)

# ---- the watchdog itself, written out to LOCALAPPDATA so it does not depend on the
# ---- Pi's Samba share being up in order to run
$watchdog = @'
# Polls Home Assistant and raises a desktop notification when it stops answering.
# State lives next to this script so the task itself stays stateless. Run by the
# "HA Watchdog" scheduled task; see install-ha-watchdog.ps1 for why this exists.

# ---- config ----
$haUrl       = '__HAURL__'
$stateFile   = Join-Path $PSScriptRoot 'state.txt'
$logFile     = Join-Path $PSScriptRoot 'watchdog.log'
$failsToWarn = __FAILSTOWARN__
$nagEvery    = __NAGEVERY__

# Append one timestamped line to the watchdog log.
function Write-Log($msg) {
    "{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg | Add-Content -Path $logFile -Encoding utf8
}

# Raise a Windows notification. Uses NotifyIcon so no extra module is needed.
function Show-Alert($title, $body) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $icon = New-Object System.Windows.Forms.NotifyIcon
    $icon.Icon = [System.Drawing.SystemIcons]::Warning
    $icon.Visible = $true
    $icon.ShowBalloonTip(20000, $title, $body, [System.Windows.Forms.ToolTipIcon]::Warning)
    Start-Sleep -Seconds 12
    $icon.Dispose()
}

# Ask HA for a page. Any HTTP response at all means the process is alive and serving;
# only a connection failure counts as down. curl.exe is used rather than
# Invoke-WebRequest so the certificate-name mismatch on the LAN IP stays a non-issue.
function Test-HomeAssistant {
    $code = & curl.exe -k -s -o NUL -m 10 -w '%{http_code}' $haUrl 2>$null
    return ($code -match '^\d{3}$' -and $code -ne '000')
}

# ---- run ----
if (-not (Test-Path $stateFile)) { Set-Content -Path $stateFile -Value '0' -Encoding utf8 }
$fails = [int](Get-Content -Path $stateFile -ErrorAction SilentlyContinue | Select-Object -First 1)

if (Test-HomeAssistant) {
    if ($fails -ge $failsToWarn) {
        Write-Log "RECOVERED after $fails consecutive failed checks"
        Show-Alert 'Home Assistant is back' "It answered again after about $($fails * __POLLMINUTES__) minutes down."
    }
    Set-Content -Path $stateFile -Value '0' -Encoding utf8
}
else {
    $fails = $fails + 1
    Set-Content -Path $stateFile -Value "$fails" -Encoding utf8
    Write-Log "no response from $haUrl (consecutive failures: $fails)"
    if ($fails -eq $failsToWarn -or ($fails -gt $failsToWarn -and (($fails - $failsToWarn) % $nagEvery) -eq 0)) {
        $mins = $fails * __POLLMINUTES__
        Show-Alert 'Home Assistant is DOWN' "No response for about $mins minutes. Automations are not running. Check the Pi."
    }
}
'@

# ---- install ----
# Substitute the config values into the watchdog body, then write it out.
$watchdog = $watchdog.Replace('__HAURL__', $haUrl).
                      Replace('__FAILSTOWARN__', "$failsToWarn").
                      Replace('__NAGEVERY__', "$nagEvery").
                      Replace('__POLLMINUTES__', "$pollMinutes")

if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
Set-Content -Path $scriptPath -Value $watchdog -Encoding utf8

# One clock-based trigger repeating forever, same shape as the heartbeat task.
$action   = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' `
            -Argument ('--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $scriptPath + '"')
$trigger  = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $pollMinutes)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

Write-Output "Registered and started scheduled task '$taskName'."
Write-Output "  checks   : $haUrl every $pollMinutes minutes"
Write-Output "  alerts   : after $failsToWarn misses (~$($failsToWarn * $pollMinutes) min), then hourly while down"
Write-Output "  script   : $scriptPath"
Write-Output "  log      : $(Join-Path $installDir 'watchdog.log')"
