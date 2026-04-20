# =============================================================================
# pack-nextjs.ps1
# Zips a Next.js project for upload/analysis, excluding:
#   - node_modules and other package directories
#   - Build output & cache directories (.next, .turbo, out, dist, build)
#   - Binary/executable files
#   - Configuration files (env, editor, CI, tooling configs)
#   - Version control metadata (.git)
#   - Log and lock files
#
# Usage:
#   .\pack-nextjs.ps1 [[-ProjectDir] <path>] [[-OutputZip] <path>]
#
# Examples:
#   .\pack-nextjs.ps1                                    # zips current dir → nextjs-project.zip
#   .\pack-nextjs.ps1 .\my-app                           # zips .\my-app    → nextjs-project.zip
#   .\pack-nextjs.ps1 .\my-app -OutputZip my-archive.zip
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ProjectDir = ".",

    [Parameter(Position = 1)]
    [string]$OutputZip = "nextjs-project.zip"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Resolve paths ─────────────────────────────────────────────────────────────
$ProjectDir = (Resolve-Path $ProjectDir).Path

if (-not [System.IO.Path]::IsPathRooted($OutputZip)) {
    $OutputZip = Join-Path (Get-Location) $OutputZip
}

Write-Host "📦  Packing Next.js project..." -ForegroundColor Cyan
Write-Host "    Source : $ProjectDir"
Write-Host "    Output : $OutputZip"
Write-Host ""

# Remove stale archive
if (Test-Path $OutputZip) { Remove-Item $OutputZip -Force }

# ── Exclusion rules ───────────────────────────────────────────────────────────
# Directories to skip entirely (matched by folder name anywhere in the tree)
$ExcludedDirs = @(
    # Dependencies
    "node_modules"
    ".pnp"

    # Build / cache
    ".next"
    "out"
    "dist"
    "build"
    ".turbo"
    ".swc"
    ".cache"
    "__pycache__"

    # VCS
    ".git"

    # Editor / IDE
    ".vscode"
    ".idea"
    ".vs"

    # CI / deployment
    ".github"
    ".circleci"
    ".vercel"
)

# File patterns to exclude (supports wildcards)
$ExcludedFilePatterns = @(
    # Environment & secrets
    ".env"
    ".env.*"
    "*.env"

    # Tooling & linting configs
    "*.config.js"
    "*.config.ts"
    "*.config.mjs"
    "*.config.cjs"
    "next.config.*"
    "postcss.config.*"
    "tailwind.config.*"
    "jest.config.*"
    "vitest.config.*"
    "playwright.config.*"
    "cypress.config.*"
    "eslint.config.*"
    ".eslintrc*"
    ".eslintignore"
    ".prettierrc*"
    ".prettierignore"
    ".stylelintrc*"
    ".babelrc*"
    "babel.config.*"
    "tsconfig*.json"
    "jsconfig*.json"
    ".browserslistrc"
    ".nvmrc"
    ".node-version"

    # Git metadata
    ".gitignore"
    ".gitattributes"
    ".gitmodules"

    # Lock files & package manager configs
    "package-lock.json"
    "yarn.lock"
    "pnpm-lock.yaml"
    "pnpm-workspace.yaml"
    "bun.lockb"
    ".yarnrc"
    ".yarnrc.yml"
    ".npmrc"
    ".pnpmfile.cjs"

    # CI / deployment configs
    ".travis.yml"
    "Dockerfile*"
    "docker-compose*"
    ".dockerignore"
    "vercel.json"
    "netlify.toml"

    # Logs & temp files
    "*.log"
    "npm-debug.log*"
    "yarn-debug.log*"
    "yarn-error.log*"
    "*.tmp"
    "*.temp"
    ".DS_Store"
    "Thumbs.db"

    # Binaries & compiled artifacts
    "*.exe"
    "*.dll"
    "*.so"
    "*.dylib"
    "*.bin"
    "*.wasm"
    "*.node"
    "*.snap"
)

# ── Collect files ─────────────────────────────────────────────────────────────
Write-Host "🔍  Scanning files..." -ForegroundColor Yellow

$AllFiles = Get-ChildItem -Path $ProjectDir -Recurse -File

$FilesToInclude = $AllFiles | Where-Object {
    $file = $_

    # Check if any ancestor directory is in the excluded list
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\', '/')
    $pathParts = $relativePath -split '[/\\]'

    $inExcludedDir = $false
    foreach ($part in $pathParts[0..($pathParts.Count - 2)]) {
        if ($ExcludedDirs -contains $part) {
            $inExcludedDir = $true
            break
        }
    }
    if ($inExcludedDir) { return $false }

    # Check if the filename matches any excluded pattern
    foreach ($pattern in $ExcludedFilePatterns) {
        if ($file.Name -like $pattern) { return $false }
    }

    return $true
}

Write-Host "    Found $($FilesToInclude.Count) files to include (of $($AllFiles.Count) total)"
Write-Host ""

# ── Build the zip ─────────────────────────────────────────────────────────────
Write-Host "🗜️   Creating archive..." -ForegroundColor Yellow

Add-Type -AssemblyName System.IO.Compression.FileSystem

$ZipStream = [System.IO.File]::Open($OutputZip, [System.IO.FileMode]::Create)
$Archive   = [System.IO.Compression.ZipArchive]::new($ZipStream, [System.IO.Compression.ZipArchiveMode]::Create)

try {
    foreach ($file in $FilesToInclude) {
        # Store with a relative path so the zip is self-contained
        $entryName = $file.FullName.Substring($ProjectDir.Length).TrimStart('\', '/').Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $Archive,
            $file.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
} finally {
    $Archive.Dispose()
    $ZipStream.Dispose()
}

# ── Summary ───────────────────────────────────────────────────────────────────
$ZipInfo  = Get-Item $OutputZip
$SizeMB   = [math]::Round($ZipInfo.Length / 1MB, 2)
$SizeKB   = [math]::Round($ZipInfo.Length / 1KB, 1)
$SizeDisplay = if ($SizeMB -ge 1) { "${SizeMB} MB" } else { "${SizeKB} KB" }

Write-Host ""
Write-Host "✅  Done!" -ForegroundColor Green
Write-Host "    Archive : $OutputZip"
Write-Host "    Size    : $SizeDisplay"
Write-Host "    Files   : $($FilesToInclude.Count)"