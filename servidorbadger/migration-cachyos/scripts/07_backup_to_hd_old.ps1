#Requires -Version 5.1
param(
    [string]$BackupRoot = "F:\BACKUP_WINDOWS",
    [string]$ProfilePath = "$env:USERPROFILE"
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$dest = Join-Path $BackupRoot $timestamp

Write-Host "Criando estrutura de backup em: $dest" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $dest -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dest "profile") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dest "configs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $dest "exports") -Force | Out-Null

function Copy-IfExists {
    param(
        [string]$Source,
        [string]$Target
    )
    if (Test-Path $Source) {
        Write-Host "Copiando: $Source" -ForegroundColor DarkGray
        robocopy $Source $Target /E /R:1 /W:1 /NFL /NDL /NP /NJH /NJS | Out-Null
    }
}

Write-Host "Backup de pastas pessoais importantes..." -ForegroundColor Yellow
$folders = @("Desktop", "Documents", "Downloads")
foreach ($f in $folders) {
    $src = Join-Path $ProfilePath $f
    $dst = Join-Path (Join-Path $dest "profile") $f
    Copy-IfExists -Source $src -Target $dst
}

Write-Host "Backup de configuracoes e credenciais..." -ForegroundColor Yellow
$items = @(
    ".ssh",
    ".gnupg",
    ".gitconfig",
    ".docker",
    "AppData\Roaming\Code\User",
    "AppData\Roaming\Cursor\User",
    "AppData\Roaming\Opera Software",
    "AppData\Local\Opera Software"
)
foreach ($item in $items) {
    $src = Join-Path $ProfilePath $item
    $name = $item.Replace("\", "_").Replace(".", "_")
    $dst = Join-Path (Join-Path $dest "configs") $name
    if (Test-Path $src) {
        if ((Get-Item $src).PSIsContainer) {
            Copy-IfExists -Source $src -Target $dst
        }
        else {
            New-Item -ItemType Directory -Path (Join-Path $dest "configs") -Force | Out-Null
            Copy-Item $src (Join-Path (Join-Path $dest "configs") (Split-Path $src -Leaf)) -Force
        }
    }
}

Write-Host "Exportando lista de apps e discos..." -ForegroundColor Yellow
Get-Volume | Format-Table DriveLetter, FileSystemLabel, FileSystem, SizeRemaining, Size -AutoSize |
Out-File (Join-Path (Join-Path $dest "exports") "volumes.txt") -Encoding UTF8
Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue |
Get-ItemProperty |
Where-Object { $_.DisplayName } |
Select-Object DisplayName, DisplayVersion, Publisher |
Sort-Object DisplayName |
Export-Csv (Join-Path (Join-Path $dest "exports") "installed-apps-hklm.csv") -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Backup de dados concluido." -ForegroundColor Green
Write-Host "Destino: $dest" -ForegroundColor Green
Write-Host "Proximo passo: backup de imagem do Windows (script 08)." -ForegroundColor Yellow
