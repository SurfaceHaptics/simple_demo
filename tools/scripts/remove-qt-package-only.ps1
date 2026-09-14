# Removes the Qt 5.15.2 PACKAGE (built binaries) from Conan cache, but KEEPS the recipe.
# This forces Conan to rebuild Qt on next build. Use after patching the Qt recipe for PNG support.
# The patched recipe uses -qt-libpng; the rebuilt Qt will have PNG support.

$ErrorActionPreference = "Stop"

$searchBases = @()
if ($env:CONAN_USER_HOME) {
    $searchBases += Join-Path $env:CONAN_USER_HOME ".conan"
    $searchBases += $env:CONAN_USER_HOME
}
$searchBases += Join-Path $env:USERPROFILE ".conan"
$searchBases += "C:\.conan"
$searchBases += "C:\conan\.conan"

$removed = $false
foreach ($base in $searchBases) {
    if (-not (Test-Path $base)) { continue }
    $qtData = Join-Path $base "data\qt\5.15.2"
    if (-not (Test-Path $qtData)) { continue }
    Get-ChildItem -Path $qtData -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "package" -or $_.Name -eq "build" } | ForEach-Object {
        $dir = $_.FullName
        if ($dir -notmatch "\\export\\" -and $dir -notmatch "\\export_source\\") {
            Write-Host "remove-qt-package: Removing $dir"
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
            $removed = $true
        }
    }
}

if ($removed) {
    Write-Host "remove-qt-package: Done. Qt will be rebuilt on next build (with patched recipe = PNG support)."
} else {
    Write-Host "remove-qt-package: No Qt package folders found to remove."
}
