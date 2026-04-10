#Requires -Version 5.1
<#
.SYNOPSIS
    Consolida saidas de auditoria e scanner em um manifesto unico de migracao.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$AuditFolder,
    [Parameter(Mandatory = $true)]
    [string]$ProjectScanFolder,
    [string]$OutputFile = "C:\migration-plan\migration-manifest.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $AuditFolder)) { throw "AuditFolder nao encontrado: $AuditFolder" }
if (-not (Test-Path $ProjectScanFolder)) { throw "ProjectScanFolder nao encontrado: $ProjectScanFolder" }

$system = Get-Content (Join-Path $AuditFolder "01_system-info.json") -Raw | ConvertFrom-Json
$apps = Import-Csv (Join-Path $AuditFolder "02_installed-apps.csv")
$runtimes = Get-Content (Join-Path $AuditFolder "04_runtimes-toolchains.json") -Raw | ConvertFrom-Json
$dirs = Import-Csv (Join-Path $AuditFolder "05_critical-dirs.csv")
$creds = Get-Content (Join-Path $AuditFolder "06_credentials-configs.json") -Raw | ConvertFrom-Json

$projects = Get-Content (Join-Path $ProjectScanFolder "projects-full.json") -Raw | ConvertFrom-Json
$projectSummary = Get-Content (Join-Path $ProjectScanFolder "projects-summary.json") -Raw | ConvertFrom-Json

$linuxMap = @{
    "Docker Desktop" = "docker + docker-compose"
    "Google Chrome" = "google-chrome"
    "VS Code" = "code"
    "Discord" = "discord"
    "Slack" = "slack-desktop"
    "Zoom" = "zoom"
    "7-Zip" = "p7zip"
    "WinRAR" = "unrar unzip"
    "Postman" = "postman-bin"
    "GitKraken" = "gitkraken"
}

$appMappings = foreach ($a in $apps) {
    $linuxEquivalent = $null
    foreach ($k in $linuxMap.Keys) {
        if ($a.DisplayName -like "*$k*") { $linuxEquivalent = $linuxMap[$k]; break }
    }
    [PSCustomObject]@{
        Name = $a.DisplayName
        Version = $a.DisplayVersion
        Publisher = $a.Publisher
        LinuxEquivalent = $linuxEquivalent
        Notes = if ($linuxEquivalent) { "mapped" } else { "manual-review" }
    }
}

$manifest = [ordered]@{
    GeneratedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    System = $system
    Summary = @{
        TotalInstalledApps = @($apps).Count
        TotalProjects = @($projects).Count
        ProjectsWithGit = $projectSummary.ProjectsWithGit
    }
    Runtimes = $runtimes
    CriticalDirectories = $dirs
    CredentialsPresence = $creds
    Apps = $appMappings
    Projects = $projects
    CachyOSInstallHints = @{
        Base = @("base-devel", "git", "curl", "wget", "openssh", "neovim")
        Dev = @("docker", "docker-compose", "nodejs", "npm", "python", "pipx", "jdk-openjdk", "maven", "gradle", "rustup", "go")
        Optional = @("code", "discord", "zoom", "slack-desktop", "google-chrome")
    }
}

$outDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$manifest | ConvertTo-Json -Depth 10 | Out-File $OutputFile -Encoding UTF8

Write-Host "Manifesto gerado em: $OutputFile" -ForegroundColor Green
