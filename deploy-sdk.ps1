# Deploy Qt + TanvasTouch SDK components next to the built exe.
# Run after building. Requires the TanvasTouch SDK installed at the default location.
#
# Usage: .\deploy-sdk.ps1 [-Config RelWithDebInfo]

param(
    [ValidateSet("Release", "Debug", "RelWithDebInfo", "MinSizeRel")]
    [string] $Config = "RelWithDebInfo"
)

$ErrorActionPreference = "Stop"
$SdkRoot = "C:\Program Files\TanvasTouch SDK"
$ProjectRoot = $PSScriptRoot
$ExeName = "PhotoFeel"

if (-not (Test-Path $SdkRoot)) {
    Write-Error "TanvasTouch SDK not found at $SdkRoot. Install the SDK first."
}

$BuildDir = Join-Path $ProjectRoot "build"

# Conan puts the exe in build/bin/, the VS generator may use build/<Config>/
$ExePath = $null
foreach ($candidate in @(
    (Join-Path $BuildDir "bin\$ExeName.exe"),
    (Join-Path $BuildDir "$Config\$ExeName.exe"),
    (Join-Path $BuildDir "$Config\bin\$ExeName.exe")
)) {
    if (Test-Path $candidate) { $ExePath = $candidate; break }
}
if (-not $ExePath) {
    Write-Error "$ExeName.exe not found. Build the project first (.\build.ps1 -Config $Config)."
}

$ExeDir = Split-Path $ExePath -Parent
Write-Host "Deploying to $ExeDir..."
Write-Host ""

# Stop the app if running so we can overwrite QTTanvasTouch.dll
$running = Get-Process -Name $ExeName -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "Stopping $ExeName (PID $($running.Id)) so SDK DLLs can be updated..."
    Stop-Process -Name $ExeName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    Write-Host ""
}

# 0. Qt DLLs (windeployqt) - required for the app to run at all
$windeployqt = $null
if (Get-Command windeployqt -ErrorAction SilentlyContinue) {
    $windeployqt = "windeployqt"
} elseif (Get-Command qmake -ErrorAction SilentlyContinue) {
    $qtBin = (Get-Command qmake).Source | Split-Path -Parent
    $wp = Join-Path $qtBin "windeployqt.exe"
    if (Test-Path $wp) { $windeployqt = $wp }
} else {
    # Conan Qt lives in the cache - search common locations
    $conanHomes = @($env:CONAN_USER_HOME, "C:\conan", "C:\.conan") | Where-Object { $_ -and (Test-Path $_) }
    foreach ($ch in $conanHomes) {
        $wp = Get-ChildItem -Path $ch -Filter "windeployqt.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($wp) { $windeployqt = $wp.FullName; break }
    }
}
if ($windeployqt) {
    Write-Host "Running windeployqt (Qt DLLs, plugins)..."
    $prevErr = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    $wdOutput = & $windeployqt --qmldir $ProjectRoot --dir $ExeDir $ExePath 2>&1
    $ErrorActionPreference = $prevErr
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  - Qt DLLs and plugins deployed"
    } else {
        Write-Host "WARNING: windeployqt returned exit code $LASTEXITCODE" -ForegroundColor Yellow
        Write-Host "  Output: $wdOutput"
    }
} else {
    Write-Host "WARNING: windeployqt not found. If the app fails with 'Qt5Core.dll not found',"
    Write-Host "         add Qt's bin directory to PATH or run windeployqt manually."
}
Write-Host ""

# 1. QML plugin (qttanvastouch) - this is what provides QTView / QTSprite
$QmlPluginDest = Join-Path $ExeDir "co\tanvas\tanvastouch"
New-Item -ItemType Directory -Path $QmlPluginDest -Force | Out-Null
Copy-Item "$SdkRoot\IntroApp\co\tanvas\tanvastouch\*" $QmlPluginDest -Force
Write-Host "  - QTTanvasTouch.dll, qmldir -> co\tanvas\tanvastouch\"

# 2. C API and C++ API DLLs (needed by QTTanvasTouch)
Copy-Item "$SdkRoot\API\C\tanvastouch.dll" $ExeDir -Force
Copy-Item "$SdkRoot\API\C++\tanvastouch-api-cpp.dll" $ExeDir -Force
Write-Host "  - tanvastouch.dll, tanvastouch-api-cpp.dll -> $ExeDir"

# 3. Any other C API dependencies shipped alongside
$CApiDeps = Get-ChildItem "$SdkRoot\API\C\*.dll" -ErrorAction SilentlyContinue
foreach ($dll in $CApiDeps) {
    if ($dll.Name -notmatch "^tanvastouch") {
        Copy-Item $dll.FullName $ExeDir -Force
        Write-Host "  - $($dll.Name) -> $ExeDir"
    }
}

# 4. qt.conf for a self-contained run (Prefix=. so the app finds plugins and QML next to the exe)
$qtConfPath = Join-Path $ExeDir "qt.conf"
@"
[Paths]
Prefix = .
Plugins = archdatadir/plugins
Imports = .
Qml2Imports = .
"@ | Set-Content -Path $qtConfPath -Encoding UTF8

# Some windeployqt versions only put QML modules in archdatadir/qml; mirror them to the top level.
$archdataQml = Join-Path $ExeDir "archdatadir\qml"
if (Test-Path $archdataQml) {
    Get-ChildItem -Path $archdataQml -Directory | ForEach-Object {
        $dest = Join-Path $ExeDir $_.Name
        if (-not (Test-Path $dest)) {
            Copy-Item $_.FullName $dest -Recurse -Force
            Write-Host "  - Copied QML module $($_.Name) to exe dir"
        }
    }
}
Write-Host "  - qt.conf (Prefix=.) -> $ExeDir"

Write-Host ""
Write-Host "SDK deployment complete."
Write-Host ""
Write-Host "IMPORTANT: Start the TanvasTouch Engine before running the app:"
Write-Host "  Start-Process `"$SdkRoot\Engine\TanvasTouch Engine.exe`""
Write-Host ""
Write-Host "Then run: $ExePath"
Write-Host ""
