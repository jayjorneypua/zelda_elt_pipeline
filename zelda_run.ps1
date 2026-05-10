$ErrorActionPreference = "Continue"
$env:PYTHONUNBUFFERED = "1"
$env:PYTHONIOENCODING = "utf-8"

$root = "C:\Users\User\Desktop\Test py"
$originalLocation = Get-Location
Set-Location $root

if (-not (Test-Path logs)) {
    New-Item -ItemType Directory -Path logs | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$log = "logs\zelda_run_$timestamp.log"

function Step {
    param([string]$Label, [scriptblock]$Action)
    "==> $Label" | Tee-Object -FilePath $log -Append
    & $Action 2>&1 | Tee-Object -FilePath $log -Append
    if ($LASTEXITCODE -ne 0) {
        "=== $Label FAILED (exit $LASTEXITCODE) ===" | Tee-Object -FilePath $log -Append
        throw "Step failed: $Label"
    }
}

try {
    "=== Starting at $(Get-Date) ===" | Tee-Object -FilePath $log

    Step "Extract from API" { py -3.12 run_all.py }

    Set-Location "$root\zelda_warehouse"

    Step "dbt snapshot" { dbt snapshot }
    Step "dbt build"    { dbt build }

    "=== Completed at $(Get-Date) ===" | Tee-Object -FilePath $log -Append
}
catch {
    Write-Host $_.Exception.Message
    $exitCode = 1
}
finally {
    Set-Location $originalLocation    
    if ($exitCode) { exit $exitCode }
}