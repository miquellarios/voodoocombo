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
    $server = Start-Process -FilePath $Engine -WorkingDirectory $projectPath -ArgumentList '--headless --path . res://tests/server_fixture.tscn -- --server --port 17777 --jitter --no-http' -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logPath/jitter-server.log" -RedirectStandardError "$logPath/jitter-server.err"
    $processes += $server
    Start-Sleep -Milliseconds 700
    foreach ($role in @('create', 'guest1')) {
        $client = Start-Process -FilePath $Engine -WorkingDirectory $projectPath -ArgumentList "--headless --path . --script res://tests/test_network_match.gd -- $role voodoo jitter" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logPath/jitter-$role.log" -RedirectStandardError "$logPath/jitter-$role.err"
        $processes += $client
        if ($role -eq 'create') {
            for ($attempt = 0; $attempt -lt 30 -and -not (Test-Path -LiteralPath $codePath); $attempt++) { Start-Sleep -Milliseconds 100 }
        }
    }
    foreach ($client in $processes[1..2]) {
        if (-not $client.WaitForExit(60000)) { throw "Jitter client timed out: $($client.Id)" }
    }
    foreach ($role in @('create','guest1')) {
        $errors = Get-Content "$logPath/jitter-$role.err"
        if ($errors -match 'SCRIPT ERROR|ERROR:') { throw ($errors -join [Environment]::NewLine) }
        if (-not (Get-Content "$logPath/jitter-$role.log" | Select-String 'MATCH PASS')) { throw "Missing network result from $role" }
    }
    $guestLog = Get-Content "$logPath/jitter-guest1.log"
    $result = $guestLog | Select-String 'JITTER RESULT'
    if (-not $result) { throw 'Jitter result was not recorded' }
    $result.ToString()
    'Three-process ENet jitter and 5% snapshot-loss test passed.'
} finally {
    foreach ($process in $processes) { if (-not $process.HasExited) { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue } }
}
