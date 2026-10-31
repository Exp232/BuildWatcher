# Registers the build watcher as a logon task for the current user. Run again to update it; -Remove deletes it.
param([switch]$Remove)
$name = 'Mod Build Watcher'
# The task's name from when the watcher was Railroader-only. It is replaced by the new one, never kept beside it.
$oldName = 'Railroader Build Watcher'
if (Get-ScheduledTask -TaskName $oldName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $oldName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $oldName -Confirm:$false
    "Removed the old '$oldName' task."
}
if ($Remove) {
    Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $name -Confirm:$false
    "Removed '$name'."
    return
}
$script = Join-Path $PSScriptRoot 'Watch-Builds.ps1'
if (-not (Test-Path (Join-Path $PSScriptRoot 'config.json'))) {
    Write-Warning 'There is no config.json yet. Copy config.example.json to config.json and list your mods, or the watcher has nothing to watch.'
}
# conhost --headless gives PowerShell a console with no window. Launched directly, Windows 11 hands the console to
# Windows Terminal, which ignores -WindowStyle Hidden; closing that window killed the watcher (0xC000013A).
$action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$script`""
# Logon starts it; the 5-minute repetition restarts it if it was killed (sleep, logoff). A running copy holds the
# mutex, so the extra starts exit at once.
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
$trigger = @((New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME), $repeat)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $name
"Registered and started '$name'."
