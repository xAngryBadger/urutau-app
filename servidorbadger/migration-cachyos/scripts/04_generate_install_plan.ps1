#Requires -Version 5.1
<#
.SYNOPSIS
    Gera um plano markdown de instalacao/migracao a partir do manifesto.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestFile,
    [string]$OutputMarkdown = "C:\migration-plan\CACHYOS_INSTALL_PLAN.md"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $ManifestFile)) { throw "Manifesto nao encontrado: $ManifestFile" }

$m = Get-Content $ManifestFile -Raw | ConvertFrom-Json
$mappedApps = @($m.Apps | Where-Object { $_.LinuxEquivalent })
$manualApps = @($m.Apps | Where-Object { -not $_.LinuxEquivalent })
$projects = @($m.Projects)

$report = @"
# Plano de Migracao Windows -> CachyOS

Gerado em: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## 1) Resumo
- Apps detectados: $($m.Summary.TotalInstalledApps)
- Projetos detectados: $($m.Summary.TotalProjects)
- Repos Git: $($m.Summary.ProjectsWithGit)

## 2) Pacotes base (CachyOS)
$(($m.CachyOSInstallHints.Base | ForEach-Object { "- $_" }) -join "`n")

## 3) Pacotes de desenvolvimento
$(($m.CachyOSInstallHints.Dev | ForEach-Object { "- $_" }) -join "`n")

## 4) Apps mapeados automaticamente
$(($mappedApps | ForEach-Object { "- $($_.Name) -> $($_.LinuxEquivalent)" }) -join "`n")

## 5) Apps para revisao manual
$(($manualApps | Select-Object -First 60 | ForEach-Object { "- $($_.Name) ($($_.Version))" }) -join "`n")

## 6) Diretorios criticos para backup
$(($m.CriticalDirectories | Where-Object { $_.Exists -eq "True" -or $_.Exists -eq $true } | ForEach-Object { "- $($_.Name): $($_.Path) ($($_.SizeGB) GB)" }) -join "`n")

## 7) Credenciais/configs (checklist)
- [ ] Copiar ~/.ssh
- [ ] Copiar ~/.gnupg
- [ ] Exportar ~/.gitconfig
- [ ] Exportar settings do VS Code/Cursor
- [ ] Revisar tokens em .npmrc/.docker/config.json/.aws

## 8) Projetos e stacks
$(($projects | Where-Object { $_.Stacks.Count -gt 0 } | Select-Object -First 80 | ForEach-Object { "- $($_.Name): $($_.Stacks.Keys -join ', ')" }) -join "`n")
"@

$outDir = Split-Path $OutputMarkdown -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$report | Out-File $OutputMarkdown -Encoding UTF8

Write-Host "Plano gerado em: $OutputMarkdown" -ForegroundColor Green
