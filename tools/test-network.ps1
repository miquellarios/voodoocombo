param([string]$Engine = "$PSScriptRoot/../build/Godot_v4.7.2-stable_win64_console.exe")
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path "$PSScriptRoot/..").Path
$env:APPDATA = Join-Path $projectPath '.godot-appdata'
$env:LOCALAPPDATA = Join-Path $projectPath '.godot-local'
$logPath = Join-Path $projectPath '.godot-tmp'
New-Item -ItemType Directory -Force -Path $logPath | Out-Null
$codePath = Join-Path $logPath 'test-room-code.txt'
if (Test-Path -LiteralPath $codePath) { Remove-Item -LiteralPath $codePath }
$processes = @()
try {
    $server = Start-Process -FilePath $Engine -WorkingDirectory $projectPath -ArgumentList '--headless --path . res://tests/server_fixture.tscn -- --server --port 17777' -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logPath/server.log" -RedirectStandardError "$logPath/server.err"
    $processes += $server
    Start-Sleep -Milliseconds 700
    foreach ($role in @('create', 'guest1', 'guest2', 'guest3', 'extra')) {
        $client = Start-Process -FilePath $Engine -WorkingDirectory $projectPath -ArgumentList "--headless --path . --script res://tests/test_network_match.gd -- $role" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logPath/$role.log" -RedirectStandardError "$logPath/$role.err"
        $processes += $client
        if ($role -eq 'create') {
            for ($attempt = 0; $attempt -lt 30 -and -not (Test-Path -LiteralPath $codePath); $attempt++) { Start-Sleep -Milliseconds 100 }
        } else { Start-Sleep -Milliseconds 200 }
    }
    foreach ($client in $processes[1..5]) {
        if (-not $client.WaitForExit(35000)) { throw 'Client timed out' }
        if ($client.ExitCode -ne 0) { throw "Client failed: $($client.Id)" }
    }
    $hashes = @()
    foreach ($role in @('create', 'guest1', 'guest2', 'guest3')) {
        $log = Get-Content "$logPath/$role.log"
        $matchLine = $log | Select-String 'MATCH PASS'
        if (-not $matchLine) { throw "Missing result from $role" }
        $hashes += ($matchLine.ToString() -split ' ')[-1]
        $matchLine.ToString()
        $clientErrors = Get-Content "$logPath/$role.err"
        if ($clientErrors -match 'SCRIPT ERROR|ERROR:') { throw ($clientErrors -join [Environment]::NewLine) }
    }
    if (($hashes | Select-Object -Unique).Count -ne 1) { throw 'Clients disagree about the ranking' }
    Get-Content "$logPath/extra.log"
    $errors = Get-Content "$logPath/server.err"
    if ($errors -match 'SCRIPT ERROR|ERROR:') { throw ($errors -join [Environment]::NewLine) }
    'Four ENet clients agree; fifth rejected; social, vote, input clamp and full match passed.'
} finally {
    foreach ($process in $processes) { if (-not $process.HasExited) { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue } }
}
