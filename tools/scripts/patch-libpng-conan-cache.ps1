# Patches the Conan cache recipe for libpng/1.6.37 to use a working source URL.
# Conan Center's recipe points to a SourceForge URL that returns 404; this script
# replaces it with the download.sourceforge.net direct URL so "conan install" succeeds.
# Run when building with TANVAS_CONAN_REMOTES=OFF (Conan Center only). After the first
# failed "conan install", the recipe is in the cache; run this script then retry the build.

$ErrorActionPreference = "Stop"
$brokenUrl = "https://sourceforge.net/projects/libpng/files/libpng16/1.6.37/libpng-1.6.37.tar.xz"
$workingUrl = "https://download.sourceforge.net/libpng/libpng16/1.6.37/libpng-1.6.37.tar.xz"

# Patch in all possible cache locations. Conan 1.x uses CONAN_USER_HOME and stores
# the cache under CONAN_USER_HOME\.conan\data\ (so when CONAN_USER_HOME=C:\conan,
# the cache is C:\conan\.conan\data\libpng\1.6.37). Default is %USERPROFILE%\.conan\data\.
$searchBases = @()
if ($env:CONAN_USER_HOME) {
    $searchBases += Join-Path $env:CONAN_USER_HOME ".conan"   # Conan 1.x: CONAN_USER_HOME\.conan\data\...
    $searchBases += $env:CONAN_USER_HOME                       # fallback: CONAN_USER_HOME\data\...
}
$searchBases += Join-Path $env:USERPROFILE ".conan"             # default: %USERPROFILE%\.conan\data\...

$patched = $false
foreach ($base in $searchBases) {
    $conanData = Join-Path $base "data\libpng\1.6.37"
    if (-not (Test-Path $conanData)) { continue }
    Get-ChildItem -Path $conanData -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        $path = $_.FullName
        $content = Get-Content -Raw -Path $path -ErrorAction SilentlyContinue
        if ($content -and $content.Contains($brokenUrl)) {
            $newContent = $content.Replace($brokenUrl, $workingUrl)
            [System.IO.File]::WriteAllText($path, $newContent, (New-Object System.Text.UTF8Encoding $false))
            Write-Host "patch-libpng-conan-cache: Patched $path"
            $patched = $true
        }
    }
}
if ($patched) {
    Write-Host "patch-libpng-conan-cache: Done. Re-run the build (e.g. .\build.ps1)."
} else {
    Write-Host "patch-libpng-conan-cache: No libpng/1.6.37 recipe with old URL found (run build once to download recipe, then retry)."
}
