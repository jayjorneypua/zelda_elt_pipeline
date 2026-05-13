# Zelda pipeline runner.
# Streams output to terminal AND a timestamped log file.
# Run manually:   .\zelda_run.ps1
# Run scheduled:  powershell.exe -ExecutionPolicy Bypass -File "C:\Users\User\Desktop\Test py\zelda_run.ps1"


# ── Settings (read once at the start) ─────────────────────────────────────────

# How PowerShell reacts to errors. "Continue" = log it but don't auto-halt.
# Our try/catch (further down) decides when to actually stop the script.
$ErrorActionPreference = "Continue"

# Tell Python to flush every line immediately instead of buffering output.
# Without this, prints can sit in memory for 30+ seconds before appearing.
$env:PYTHONUNBUFFERED = "1"

# Tell Python to use UTF-8 for output. Avoids encoding crashes on Windows
# when log messages contain non-ASCII characters.
$env:PYTHONIOENCODING = "utf-8"


# ── Remember where we started, then move into the project folder ─────────────

# Absolute path to the project root. Used later for the log file path.
$root = "C:\Users\User\Desktop\Test py"

# Save whatever folder PowerShell was in BEFORE we ran this script.
# We'll restore this at the end so the script doesn't leave the user's
# terminal stranded in zelda_warehouse/.
$originalLocation = Get-Location

# Change PowerShell's current directory to the project root.
# Same as: cd "C:\Users\User\Desktop\Test py"
Set-Location $root

# If a folder named "logs" doesn't exist here, create it.
# Test-Path returns True/False; -not flips it.
if (-not (Test-Path logs)) {
    # New-Item creates the folder. Its output (info about what was created)
    # is piped to Out-Null so it doesn't clutter the terminal.
    New-Item -ItemType Directory -Path logs | Out-Null
}


# ── Build the log file path with a timestamp ──────────────────────────────────

# Current date/time formatted as "2026-05-12_09-00-02".
# yyyy = year, MM = month, dd = day, HH = hour (24h), mm = minute, ss = second.
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Build an ABSOLUTE path to the log file.
# Join-Path stitches paths together correctly (handles slashes).
# Absolute matters because we'll cd into zelda_warehouse/ later, but the log
# should always go to the same place no matter what the current directory is.
$log = Join-Path $root "logs\zelda_run_$timestamp.log"


# ── Helper function: run one phase of the pipeline ───────────────────────────

# Step is reusable code we call 3 times below (extract, snapshot, build).
# What it does:
#   1. Logs a "==> [label]" header to console + file
#   2. Runs the code you passed in
#   3. Captures all its output to console + file
#   4. If the code failed, logs a FAILED marker and THROWS an error
#      (a "throw" interrupts normal flow and jumps to the nearest catch block)
function Step {

    # Two inputs: a label string, and a scriptblock (chunk of code in { }).
    param([string]$Label, [scriptblock]$Action)

    # Write the phase header to console AND log file.
    # Tee-Object splits the output stream into both places.
    # -Append means "add to the file, don't overwrite it."
    "==> $Label" | Tee-Object -FilePath $log -Append

    # Run the scriptblock.
    #   & = "execute this scriptblock" (without &, $Action would just be a value)
    #   2>&1 = merge error stream into normal output, so errors get logged too
    #   | Tee-Object ... = send all output to console + log file
    & $Action 2>&1 | Tee-Object -FilePath $log -Append

    # $LASTEXITCODE is auto-set by PowerShell to the exit code of the last command.
    # 0 = success; anything else = failure.
    # -ne means "not equal." So this reads: "if the last command failed..."
    if ($LASTEXITCODE -ne 0) {

        # Write a failure marker to console + log so you can spot it later.
        "=== $Label FAILED (exit $LASTEXITCODE) ===" | Tee-Object -FilePath $log -Append

        # "throw" raises an error that the try/catch below will catch.
        # We use throw instead of "exit 1" so that the "finally" block
        # downstream still runs (and restores the original directory).
        throw "Step failed: $Label"
    }
}


# ── Run the pipeline (with try/catch/finally so cleanup ALWAYS happens) ──────

# try = "run this code; if any throw happens, jump to catch"
try {
    # Header line in console + log. Note: NO -Append on this first Tee-Object,
    # so the log file is freshly created with this line at the top.
    # $(...) is a subexpression — runs Get-Date and embeds the result in the string.
    "=== Starting at $(Get-Date) ===" | Tee-Object -FilePath $log

    # Phase 1: run all the Python extractors.
    # The { py -3.12 run_all.py } part is the scriptblock passed to Step.
    Step "Extract from API" { py -3.12 run_all.py }

    # Move into the dbt project folder (dbt has to run from there).
    Set-Location "$root\zelda_warehouse"

    # Phase 2: run dbt snapshots.
    Step "dbt snapshot" { dbt snapshot }

    # Phase 3: run dbt models + tests in dependency order.
    Step "dbt build" { dbt build }

    # If we made it here, everything succeeded. Footer line.
    "=== Completed at $(Get-Date) ===" | Tee-Object -FilePath $log -Append
}

# catch = "if anything in the try block threw, run this code"
catch {
    # $_ is the automatic variable for "the error that was caught".
    # .Exception.Message is the human-readable error text.
    # Write-Host prints to terminal (and goes through Tee-Object captures elsewhere).
    Write-Host $_.Exception.Message

    # Set a variable to 1 so the finally block knows we want to exit with failure.
    $exitCode = 1
}

# finally = "ALWAYS run this, whether try succeeded or catch ran"
# Useful for cleanup — restoring state, closing connections, etc.
finally {
    # Put PowerShell back where the user was BEFORE the script ran.
    # Saves them from ending up stuck inside zelda_warehouse/ after a manual run.
    Set-Location $originalLocation

    # If $exitCode was set (i.e., catch ran), exit with that code.
    # If everything succeeded, $exitCode is $null, which is falsy, so we skip.
    # Task Scheduler reads this exit code to mark the run as success or failure.
    if ($exitCode) { exit $exitCode }
}