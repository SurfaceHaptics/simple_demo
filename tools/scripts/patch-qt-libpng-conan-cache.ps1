# Patches the Qt recipe in the Conan cache to use -qt-libpng (Qt bundled) when with_libpng=False.
# This enables PNG image support without Conan's libpng (avoids system-png and LNK2019 errors).
# Run before build. If Qt was already built with -no-libpng, run: conan remove qt/5.15.2 -f
# Then run this script, then build.

$ErrorActionPreference = "Stop"

# Search in all possible Conan cache locations (Conan 1 stores data in .conan/data or directly)
$searchBases = @()
if ($env:CONAN_USER_HOME) {
    $searchBases += Join-Path $env:CONAN_USER_HOME ".conan"
    $searchBases += $env:CONAN_USER_HOME
}
$searchBases += Join-Path $env:USERPROFILE ".conan"
$searchBases += "C:\.conan"
$searchBases += "C:\conan\.conan"
$searchBases += "C:\conan"

$patched = $false
foreach ($base in $searchBases) {
    if (-not (Test-Path $base)) { continue }
    $qtData = Join-Path $base "data\qt\5.15.2"
    if (-not (Test-Path $qtData)) { continue }
    Get-ChildItem -Path $qtData -Recurse -Filter "conanfile.py" -ErrorAction SilentlyContinue | ForEach-Object {
        $path = $_.FullName
        $content = Get-Content -Raw -Path $path -ErrorAction SilentlyContinue
        if (-not $content) { return }
        if ($content.Contains('if conf_arg == "libpng"')) { return }  # Already patched
        if (-not $content.Contains('args += ["-no-" + conf_arg]')) { return }

        # Replace the else block - handle different line endings. $1 = captured indentation.
        $replacement = '${1}else:' + "`n" + '${1}    # Use Qt bundled libpng when with_libpng=False (avoids Conan libpng LNK2019, keeps PNG support)' + "`n" + '${1}    if conf_arg == "libpng":' + "`n" + '${1}        args += ["-qt-" + conf_arg]' + "`n" + '${1}    else:' + "`n" + '${1}        args += ["-no-" + conf_arg]'
        $newContent = $content -replace '(\s+)else:\r?\n\s+args \+= \["-no-" \+ conf_arg\]', $replacement
        if ($newContent -ne $content) {
            [System.IO.File]::WriteAllText($path, $newContent, (New-Object System.Text.UTF8Encoding $false))
            Write-Host "patch-qt-libpng: Patched $path"
            $patched = $true
        }
    }
}

if ($patched) {
    Write-Host "patch-qt-libpng: Done. Retrying configure..."
} else {
    Write-Host "patch-qt-libpng: No unpatched Qt 5.15.2 recipe found. Run a build first to download the recipe, or Qt may already be patched."
}
