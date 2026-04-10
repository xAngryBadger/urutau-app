#Requires -Version 5.1
<#
.SYNOPSIS
    Escaneia repos/projetos para detectar stacks e arquivos de build reais.
#>

param(
    [Parameter(Mandatory = $true)]
    [string[]]$ProjectPaths,
    [string]$OutputDir = "C:\migration-plan\audit-output",
    [int]$MaxDepth = 4
)

$ErrorActionPreference = "SilentlyContinue"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputPath = Join-Path $OutputDir $timestamp
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

$patterns = @{
    NodeJS    = @("package.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb")
    Python    = @("requirements.txt", "pyproject.toml", "Pipfile", "setup.py", "poetry.lock", "uv.lock")
    Java      = @("pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts")
    DotNet    = @("*.sln", "*.csproj", "*.fsproj", "global.json")
    Rust      = @("Cargo.toml", "Cargo.lock")
    Go        = @("go.mod", "go.sum")
    Docker    = @("Dockerfile", "docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")
    Terraform = @("*.tf", ".terraform.lock.hcl")
}

function Test-PatternInDir {
    param([string]$Dir, [string]$Pattern)
    if ($Pattern.Contains("*")) {
        return @(Get-ChildItem -Path $Dir -File -Filter $Pattern -ErrorAction SilentlyContinue).Count -gt 0
    }
    return Test-Path (Join-Path $Dir $Pattern)
}

$projects = @()
foreach ($base in $ProjectPaths) {
    if (-not (Test-Path $base)) { continue }

    $baseFull = (Get-Item $base).FullName
    $baseDepth = ($baseFull -split "[\\/]").Count
    $dirs = @($baseFull)
    $dirs += Get-ChildItem -Path $baseFull -Directory -Recurse -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch "\\(node_modules|\.git|\.venv|venv|dist|build|target|bin|obj)(\\|$)" -and
        ((($_.FullName -split "[\\/]").Count - $baseDepth) -le $MaxDepth)
    } |
    Select-Object -ExpandProperty FullName

    foreach ($dir in $dirs) {
        $detected = @{}
        foreach ($eco in $patterns.Keys) {
            $hits = @()
            foreach ($p in $patterns[$eco]) {
                if (Test-PatternInDir -Dir $dir -Pattern $p) { $hits += $p }
            }
            if ($hits.Count -gt 0) { $detected[$eco] = @($hits | Select-Object -Unique) }
        }

        $isGit = Test-Path (Join-Path $dir ".git")
        if ($detected.Count -eq 0 -and -not $isGit) { continue }

        $files = Get-ChildItem -Path $dir -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\(node_modules|\.git|\.venv|venv|dist|build|target|bin|obj)(\\|$)" } |
        Select-Object -First 15000
        $sizeMb = [math]::Round((($files | Measure-Object Length -Sum).Sum / 1MB), 2)

        $row = [ordered]@{
            Name         = (Split-Path $dir -Leaf)
            Path         = $dir
            GitRepo      = $isGit
            Stacks       = $detected
            FileCount    = $files.Count
            SizeMB       = $sizeMb
            RuntimeHints = @{}
        }

        if (Test-Path (Join-Path $dir ".nvmrc")) {
            $row.RuntimeHints.Node = (Get-Content (Join-Path $dir ".nvmrc") -Raw).Trim()
        }
        if (Test-Path (Join-Path $dir ".python-version")) {
            $row.RuntimeHints.Python = (Get-Content (Join-Path $dir ".python-version") -Raw).Trim()
        }
        if (Test-Path (Join-Path $dir "go.mod")) {
            $goMod = Get-Content (Join-Path $dir "go.mod") -Raw
            if ($goMod -match "go\s+(\d+\.\d+)") { $row.RuntimeHints.Go = $matches[1] }
        }

        $projects += $row
    }
}

$summary = [ordered]@{
    TotalProjects      = $projects.Count
    ProjectsWithGit    = @($projects | Where-Object { $_.GitRepo }).Count
    MultiStackProjects = @($projects | Where-Object { $_.Stacks.Count -gt 1 }).Count
    Ecosystems         = @{}
}
foreach ($eco in $patterns.Keys) {
    $summary.Ecosystems[$eco] = @($projects | Where-Object { $_.Stacks.Contains($eco) }).Count
}

$projects | ConvertTo-Json -Depth 8 | Out-File (Join-Path $outputPath "projects-full.json") -Encoding UTF8
$summary | ConvertTo-Json -Depth 6 | Out-File (Join-Path $outputPath "projects-summary.json") -Encoding UTF8
$projects | Select-Object Name, Path, GitRepo, FileCount, SizeMB, @{ N = "Stacks"; E = { $_.Stacks.Keys -join ";" } } |
Export-Csv (Join-Path $outputPath "projects-list.csv") -NoTypeInformation -Encoding UTF8

$toolchains = @()
if ($summary.Ecosystems.NodeJS -gt 0) { $toolchains += "nodejs fnm npm pnpm yarn" }
if ($summary.Ecosystems.Python -gt 0) { $toolchains += "python uv pyenv" }
if ($summary.Ecosystems.Java -gt 0) { $toolchains += "jdk-openjdk maven gradle" }
if ($summary.Ecosystems.DotNet -gt 0) { $toolchains += "dotnet-sdk" }
if ($summary.Ecosystems.Rust -gt 0) { $toolchains += "rustup" }
if ($summary.Ecosystems.Go -gt 0) { $toolchains += "go" }
if ($summary.Ecosystems.Docker -gt 0) { $toolchains += "docker docker-compose" }
if ($summary.Ecosystems.Terraform -gt 0) { $toolchains += "terraform" }
$toolchains | Out-File (Join-Path $outputPath "required-toolchains.txt") -Encoding UTF8

Write-Host "Scan concluido: $outputPath" -ForegroundColor Green
