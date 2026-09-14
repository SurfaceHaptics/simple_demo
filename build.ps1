# PhotoFeel - minimal TanvasTouch photo demo. Local build script (Windows)
#
# Prerequisites:
#   - Visual Studio 2022 with "Desktop development with C++"
#   - CMake >= 3.13
#   - Conan 1.x (pip install "conan<2") - this project's conanfile and CMake use Conan 1 API
#   - Optional: set CONAN_CMD to full path to conan.exe if it is not on PATH
#
# Usage:
#   .\build.ps1              # Configure and build (RelWithDebInfo)
#   .\build.ps1 -Config Debug
#   .\build.ps1 -Clean       # Remove build dir and reconfigure
#   .\build.ps1 -Clean -CleanCache   # Also wipe Conan cache (fixes Qt LNK2019 zlib errors)

param(
    [ValidateSet("Release", "Debug", "RelWithDebInfo", "MinSizeRel")]
    [string] $Config = "RelWithDebInfo",
    [switch] $Clean,
    [switch] $CleanCache,  # With -Clean: remove entire Conan cache (fixes corrupted Qt build)
    [switch] $BuildOnly,   # Skip configure, just run build
    [switch] $ForceQtRebuild  # Remove Qt package to force rebuild (fixes "Unsupported image format")
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$BuildDir = Join-Path $ProjectRoot "build"
$ConanProfilePath = Join-Path $ProjectRoot "tools\profiles\Windows-x64-msvc17-MD"
$ExeName = "PhotoFeel"

# Ensure Conan is findable (CMake/conan.cmake checks PATH and CONAN_CMD)
if (-not (Get-Command conan -ErrorAction SilentlyContinue)) {
    $conanExe = $null
    $candidates = @(
        (Get-ChildItem "$env:LOCALAPPDATA\Packages\PythonSoftwareFoundation.Python.*\LocalCache\local-packages\Python*\Scripts\conan.exe" -ErrorAction SilentlyContinue | Select-Object -First 1),
        (Get-ChildItem "$env:APPDATA\Python\Python*\Scripts\conan.exe" -ErrorAction SilentlyContinue | Select-Object -First 1)
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c.FullName)) { $conanExe = $c.FullName; break }
    }
    if ($conanExe) {
        $env:CONAN_CMD = $conanExe
        Write-Host "Using Conan at: $conanExe"
    } else {
        Write-Host "Conan not found. Install with: pip install ""conan<2"""
        exit 1
    }
}

# Resolve profile to absolute path; forward slashes so CMake does not treat backslashes as escapes
$ConanProfilePath = (Resolve-Path $ConanProfilePath).Path -replace '\\', '/'

# Short Conan cache path keeps Qt configure under the Windows command-line length limit
if (-not $env:CONAN_USER_HOME) {
    $shortConanHome = "C:\conan"
    if (Test-Path $shortConanHome) { $env:CONAN_USER_HOME = $shortConanHome }
}

if ($Clean) {
    if (Test-Path $BuildDir) {
        Write-Host "Removing existing build directory..."
        Remove-Item -Recurse -Force $BuildDir
    }
    $conanArtifacts = @(
        "conanbuildinfo.cmake", "conanbuildinfo.txt", "conaninfo.txt", "conan.lock",
        "conan_imports_manifest.txt", "qt.conf",
        "activate.ps1", "activate.bat", "activate.sh",
        "deactivate.ps1", "deactivate.bat", "deactivate.sh",
        "environment.ps1.env", "environment.bat.env", "environment.sh.env"
    )
    foreach ($f in $conanArtifacts) {
        $p = Join-Path $ProjectRoot $f
        if (Test-Path $p) { Remove-Item -Force $p; Write-Host "Removed $f from project root" }
    }
    Get-ChildItem -Path $ProjectRoot -Filter "*-config.cmake" -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $ProjectRoot -Filter "*Targets.cmake" -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $ProjectRoot -Filter "*Target-*.cmake" -ErrorAction SilentlyContinue | Remove-Item -Force
    if ($CleanCache) {
        # Nuclear option: wipe entire Conan cache. Fixes Qt LNK2019 (inflate, deflate, zlib) errors
        $cachePaths = @(
            $env:CONAN_USER_HOME,
            (Join-Path $env:USERPROFILE ".conan"),
            "C:\.conan",
            "C:\conan"
        ) | Where-Object { $_ -and (Test-Path $_) }
        foreach ($p in $cachePaths) {
            Write-Host "Removing Conan cache: $p"
            Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue
        }
    } else {
        $conanExe = if ($env:CONAN_CMD) { $env:CONAN_CMD } else { "conan" }
        Write-Host "Removing cached qt/5.15.2 to force rebuild with correct options..."
        $prevErr = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        & $conanExe remove "qt/5.15.2" -f 2>&1 | Out-Null
        $ErrorActionPreference = $prevErr
    }
}

# Stop a running instance so Conan can copy DLLs to build/bin (avoids WinError 32)
$procs = Get-Process -Name $ExeName -ErrorAction SilentlyContinue
if ($procs) {
    Write-Host "Stopping running $ExeName.exe to avoid file lock during Conan imports..."
    $procs | Stop-Process -Force
    Start-Sleep -Seconds 1
}

if (-not $BuildOnly) {
    if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir | Out-Null }

    if (-not $env:CONAN_USER_HOME) {
        $shortConanHome = "C:\conan"
        if (-not (Test-Path $shortConanHome)) {
            try {
                New-Item -ItemType Directory -Path $shortConanHome -Force | Out-Null
                Write-Host "Using Conan cache at $shortConanHome (short path for Qt configure)."
            } catch {
                Write-Host "Could not create $shortConanHome ; Qt configure may fail. Set CONAN_USER_HOME yourself."
            }
        }
        if (Test-Path $shortConanHome) { $env:CONAN_USER_HOME = $shortConanHome }
    }

    if ($ForceQtRebuild) {
        $removeQtPkgScript = Join-Path $ProjectRoot "tools\scripts\remove-qt-package-only.ps1"
        if ((Test-Path $removeQtPkgScript)) { & $removeQtPkgScript }
    }

    # Fetch Qt recipe into cache if missing (so the patch below can find it).
    $conanExe = if ($env:CONAN_CMD) { $env:CONAN_CMD } else { "conan" }
    $prevErr = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    try {
        & $conanExe install (Join-Path $ProjectRoot "conanfile.py") "-if=$BuildDir" "-pr=$ConanProfilePath" "-s" "arch=x86_64" "-s" "build_type=$Config" "-s" "compiler=Visual Studio" "-s" "compiler.version=17" "-s" "compiler.runtime=MD" "--build=never" "-o=use_tanvas_remotes=False" "-o=qt:with_freetype=False" "-o=qt:with_libpng=False" 2>&1 | Out-Null
    } catch { }
    $ErrorActionPreference = $prevErr

    # Patch libpng/1.6.37 recipe in Conan cache if present (broken SourceForge URL).
    $patchScript = Join-Path $ProjectRoot "tools\scripts\patch-libpng-conan-cache.ps1"
    if ((Test-Path $patchScript)) { & $patchScript | Out-Null }
    # Patch Qt recipe to use -qt-libpng when with_libpng=False (enables PNG without Conan libpng).
    $patchQtScript = Join-Path $ProjectRoot "tools\scripts\patch-qt-libpng-conan-cache.ps1"
    if ((Test-Path $patchQtScript)) { & $patchQtScript | Out-Null }

    Write-Host "Configuring PhotoFeel (Config=$Config)..."
    Push-Location $BuildDir
    try {
        cmake -G "Visual Studio 17 2022" -A x64 `
            -DCMAKE_BUILD_TYPE="$Config" `
            -DTANVAS_CONAN_PROFILE="$ConanProfilePath" `
            -DTANVAS_ARCH=x86_64 `
            -DTANVAS_CONAN_REMOTES=OFF `
            $ProjectRoot
        if ($LASTEXITCODE -ne 0) {
            if ((Test-Path $patchScript)) { Write-Host "Patching libpng recipe..."; & $patchScript }
            if ((Test-Path $patchQtScript)) {
                Write-Host "Patching Qt recipe (qt-libpng for PNG support)..."
                & $patchQtScript
            }
            Write-Host "Retrying configure..."
            cmake -G "Visual Studio 17 2022" -A x64 `
                -DCMAKE_BUILD_TYPE="$Config" `
                -DTANVAS_CONAN_PROFILE="$ConanProfilePath" `
                -DTANVAS_ARCH=x86_64 `
                -DTANVAS_CONAN_REMOTES=OFF `
                $ProjectRoot
            if ($LASTEXITCODE -ne 0) { throw "CMake configure failed." }
        }
    }
    finally { Pop-Location }
}

Write-Host "Building..."
Push-Location $BuildDir
try {
    cmake --build . --config $Config
    if ($LASTEXITCODE -ne 0) { throw "Build failed." }
}
finally { Pop-Location }

$ExeInConfig = Join-Path $BuildDir "$Config\$ExeName.exe"
$ExeInBin = Join-Path $BuildDir "bin\$ExeName.exe"
if (Test-Path $ExeInConfig) {
    Write-Host ""
    Write-Host "Build succeeded: $ExeInConfig"
} elseif (Test-Path $ExeInBin) {
    Write-Host ""
    Write-Host "Build succeeded: $ExeInBin"
} else {
    Write-Host "Build finished. Look for $ExeName.exe under build\"
}

$SdkRoot = "C:\Program Files\TanvasTouch SDK"
if (Test-Path $SdkRoot) {
    Write-Host ""
    Write-Host "TanvasTouch SDK detected. To enable haptics, run:"
    Write-Host "  .\deploy-sdk.ps1 -Config $Config"
    Write-Host ""
}
