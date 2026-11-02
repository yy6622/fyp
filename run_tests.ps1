# Voya - runs every executable test case and collects the results.
#
#   .\run_tests.ps1                      # everything
#   .\run_tests.ps1 -Only unit,functions # just some layers
#   .\run_tests.ps1 -Device emulator-5554
#   .\run_tests.ps1 -EmulatorHost 192.168.1.20   # real phone instead of the Android emulator
#
# Layers:
#   unit         Dart unit tests (test/unit)                       - no device needed
#   functions    Cloud Functions tests (tests/functions)           - Node only
#   integration  Flutter integration tests (integration_test)      - Android emulator + Firebase emulators
#   web          Admin / partner console tests (tests/web)         - Chrome via Playwright + Firebase emulators
#   live         Stripe test-mode payments (tests/live)            - needs $env:STRIPE_TEST_SECRET_KEY
#
# Results: test_results\summary.md, summary.csv and by_test_case.csv (paste into Chapter 5).
param(
  [string[]]$Only = @("unit", "functions", "integration", "web", "live"),
  [string]$Device = "",
  [string]$EmulatorHost = "10.0.2.2"
)

$ErrorActionPreference = "Continue"
# From a .cmd file (powershell -File) "-Only integration,web" arrives as one string; split it.
$Only = @($Only | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
Write-Host "Layers to run: $($Only -join ', ')"
$root = $PSScriptRoot
Set-Location $root
$results = Join-Path $root "test_results"
New-Item -ItemType Directory -Force $results | Out-Null
if (-not (Test-Path "$results\manual_results.csv")) {
  Copy-Item "$root\tests\manual_results_template.csv" "$results\manual_results.csv"
}

function Step($title) { Write-Host "`n=== $title ===" -ForegroundColor Cyan }
$deviceArg = if ($Device) { "-d $Device" } else { "" }

# The Firebase emulators need Java 21+. If the default java is older, fall back
# to the Java runtime bundled with Android Studio (jbr), or a JDK 21+ under
# Program Files, for this run only.
function Get-JavaMajor($javaExe) {
  try {
    $out = (& $javaExe -version 2>&1 | Out-String)
    if ($out -match 'version "(\d+)') { return [int]$Matches[1] }
  } catch {}
  return 0
}
function Use-Java21 {
  $current = Get-JavaMajor "java"
  if ($current -ge 21) { Write-Host "Java $current found."; return $true }
  $candidates = @(
    "$env:ProgramFiles\Android\Android Studio\jbr",
    "$env:LOCALAPPDATA\Programs\Android Studio\jbr",
    "$env:LOCALAPPDATA\Programs\Android Studio\jre"
  )
  $candidates += Get-ChildItem "$env:LOCALAPPDATA\JetBrains\Toolbox\apps\AndroidStudio" -Directory -Recurse -Filter jbr -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
  foreach ($root in @("$env:ProgramFiles\Eclipse Adoptium", "$env:ProgramFiles\Java", "$env:ProgramFiles\Microsoft")) {
    $candidates += Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
  }
  foreach ($jdk in $candidates) {
    $exe = Join-Path $jdk "bin\java.exe"
    if ((Test-Path $exe) -and ((Get-JavaMajor $exe) -ge 21)) {
      $env:JAVA_HOME = $jdk
      $env:Path = "$jdk\bin;$env:Path"
      Write-Host "Default Java is $current; using Java $(Get-JavaMajor $exe) from $jdk for the emulators."
      return $true
    }
  }
  Write-Host "No Java 21+ found (default is Java $current). Install Temurin 21 from adoptium.net, then run again." -ForegroundColor Red
  return $false
}

function Test-AndroidDevice {
  $adb = "adb"
  if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" }
  $out = (& $adb devices 2>&1 | Out-String)
  if ($out -match "emulator-\d+\s+device") { return $true }
  Write-Host "No running Android emulator found (adb devices):" -ForegroundColor Red
  Write-Host $out
  return $false
}

if ($Only -contains "unit") {
  Step "Dart unit tests"
  flutter pub get | Out-Null
  flutter test test/unit --file-reporter "json:test_results/unit.json"
}

if ($Only -contains "functions" -or $Only -contains "live") {
  if (-not (Test-Path "$root\functions\node_modules")) {
    Step "Installing Cloud Functions dependencies"
    Push-Location functions; npm ci; Pop-Location
  }
}

if ($Only -contains "functions") {
  Step "Cloud Functions tests"
  node --test --test-reporter=spec --test-reporter-destination=stdout `
    --test-reporter=junit --test-reporter-destination=test_results/functions-junit.xml `
    tests/functions/cloud_functions.test.js
}

if ($Only -contains "live") {
  Step "Live Stripe test-mode payments"
  if (-not $env:STRIPE_TEST_SECRET_KEY) {
    Write-Host 'Skipped: set $env:STRIPE_TEST_SECRET_KEY = "sk_test_..." to run TC32/TC33 against Stripe.' -ForegroundColor Yellow
  }
  node --test --test-reporter=spec --test-reporter-destination=stdout `
    --test-reporter=junit --test-reporter-destination=test_results/live-junit.xml `
    tests/live/stripe_live.test.js
}

# The Firebase emulators need these ports free. Report what holds any that are taken.
function Test-EmulatorPorts {
  $ok = $true
  foreach ($port in 9099, 8085, 9199) {
    $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) {
      $p = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
      Write-Host "Port $port is already used by $($p.ProcessName) (PID $($c.OwningProcess)). Close it (Task Manager > Details) and run again." -ForegroundColor Red
      $ok = $false
    }
  }
  return $ok
}

if ($Only -contains "integration" -or $Only -contains "web") { $javaOk = (Use-Java21) -and (Test-EmulatorPorts) }

if ($Only -contains "integration" -and $javaOk -and (Test-AndroidDevice)) {
  Step "Flutter integration tests (start an Android emulator first)"
  flutter pub get | Out-Null
  $cmd = "flutter test integration_test $deviceArg --dart-define=EMULATOR_HOST=$EmulatorHost --file-reporter json:test_results/integration.json"
  firebase emulators:exec --only auth,firestore,storage "$cmd"
}

if ($Only -contains "web" -and $javaOk) {
  Step "Web console tests"
  if (-not (Test-Path "$root\tests\node_modules\@playwright\test")) {
    Push-Location tests; npm install; npx playwright install chromium; Pop-Location
  }
  firebase emulators:exec --only auth,firestore,storage "node tests/node_modules/@playwright/test/cli.js test -c tests/web/playwright.config.js"
}

Step "Collecting results"
node tools/collect_results.js
Write-Host "`nOpen test_results\summary.md (or by_test_case.csv) for the table." -ForegroundColor Green
Write-Host "Fill in test_results\manual_results.csv for the manual cases, then run: node tools/collect_results.js" -ForegroundColor Green
