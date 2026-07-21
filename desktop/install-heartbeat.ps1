# Installs the desktop-side heartbeat for the Home Assistant "Wake Desktop" tile.
# Registers a per-user scheduled task that POSTs the HA heartbeat webhook once a
# minute while logged on (locked screen included; heartbeats stop on sleep,
# shutdown, or sign-out), which drives binary_sensor.desktop_on. conhost
# --headless runs curl with no console window, so nothing flashes each minute;
# wscript/VBScript is avoided because Task Scheduler runs of wscript exit 1 on
# this machine and VBScript is deprecated anyway. curl uses -k because HA is
# reached by LAN IP while its certificate names the DuckDNS host; the webhook is
# local_only on the HA side and carries no data. No admin rights needed. Safe to
# re-run anytime; it replaces the existing task.
# Remove with: Unregister-ScheduledTask -TaskName 'HA Desktop Heartbeat' -Confirm:$false

$taskName = 'HA Desktop Heartbeat'
$webhookUrl = 'https://192.168.0.100:8123/api/webhook/desktop-heartbeat-e9f6ccd24a0242d9870d86a50f04eceea1a3d2685e4a43a5a6b2a99295bcf178'

# One clock-based trigger repeating every minute forever (omitting
# RepetitionDuration means indefinite; Task Scheduler rejects TimeSpan.MaxValue).
# Repetition survives reboots; ticks that land while logged off or asleep are
# skipped and resume on the next tick after logon or wake.
$action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\conhost.exe' -Argument ('--headless curl.exe -k -s -m 5 -X POST ' + $webhookUrl)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Output "Registered and started scheduled task '$taskName' (POSTs heartbeat every 1 minute)."
