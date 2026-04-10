#Requires -Version 5.1
<#
.SYNOPSIS
    Auditoria somente leitura para planejar migracao Windows -> CachyOS.
.DESCRIPTION
    Coleta:
    1) Informacoes do sistema
    2) Programas instalados (HKLM 64/32 + HKCU)
    3) Gerenciadores de pacotes (winget/choco/scoop)
    4) Toolchains e runtimes
    5) Diretorios criticos e tamanhos
    6) Presenca de credenciais/configs
#>

param(
    [string]$OutputDir = "C:\migration-plan\audit-output"
)

$ErrorActionPreference = "SilentlyContinue"
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Aviso: executando sem elevacao. Alguns itens podem vir incompletos." -ForegroundColor Yellow
}
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputPath = Join-Path $OutputDir $timestamp
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

Write-Host "[1/6] Sistema"
$systemInfo = [ordered]@{
    ComputerName    = $env:COMPUTERNAME
    WindowsEdition  = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
    WindowsBuild    = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
    OSVersion       = [Environment]::OSVersion.VersionString
    Architecture    = if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
    Username        = $env:USERNAME
    UserProfile     = $env:USERPROFILE
    CollectedAt     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
$systemInfo | ConvertTo-Json -Depth 3 | Out-File (Join-Path $outputPath "01_system-info.json") -Encoding UTF8

Write-Host "[2/6] Apps instalados"
function Get-InstalledAppsFromKey {
    param([string]$KeyPath, [string]$SourceTag)

    Get-ChildItem $KeyPath -ErrorAction SilentlyContinue |
        Get-ItemProperty |
        Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation, UninstallString, @{ N = "Source"; E = { $SourceTag } }
}

$apps = @()
$apps += Get-InstalledAppsFromKey "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" "HKLM_64bit"
$apps += Get-InstalledAppsFromKey "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" "HKLM_32bit"
$apps += Get-InstalledAppsFromKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall" "HKCU_User"

$apps | Sort-Object DisplayName | Export-Csv (Join-Path $outputPath "02_installed-apps.csv") -NoTypeInformation -Encoding UTF8
$apps | Select-Object DisplayName, DisplayVersion, Publisher, Source | Sort-Object DisplayName |
    Out-File (Join-Path $outputPath "02_installed-apps-summary.txt") -Encoding UTF8

Write-Host "[3/6] Package managers"
$pm = [ordered]@{}
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $wingetRaw = winget list 2>$null
    $wingetRaw | Out-File (Join-Path $outputPath "03_winget-list.txt") -Encoding UTF8
    $pm.Winget = @($wingetRaw).Count
}
if (Get-Command choco -ErrorAction SilentlyContinue) {
    $chocoRaw = choco list --local-only 2>$null
    $chocoRaw | Out-File (Join-Path $outputPath "03_chocolatey-list.txt") -Encoding UTF8
    $pm.Chocolatey = @($chocoRaw).Count
}
if (Test-Path "$env:USERPROFILE\scoop\apps") {
    $scoopApps = Get-ChildItem "$env:USERPROFILE\scoop\apps" -Directory | Select-Object -ExpandProperty Name
    $scoopApps | Out-File (Join-Path $outputPath "03_scoop-list.txt") -Encoding UTF8
    $pm.Scoop = @($scoopApps).Count
}
$pm | ConvertTo-Json -Depth 3 | Out-File (Join-Path $outputPath "03_package-managers.json") -Encoding UTF8

Write-Host "[4/6] Runtimes/toolchains"
function Get-Tool {
    param([string]$Cmd, [string]$Arg = "--version")
    $ref = Get-Command $Cmd -ErrorAction SilentlyContinue
    if (-not $ref) { return @{ Installed = $false; Path = $null; Version = $null } }
    $v = (& $Cmd $Arg 2>&1 | Select-Object -First 1)
    return @{ Installed = $true; Path = $ref.Source; Version = "$v" }
}

$runtimes = [ordered]@{
    Node      = Get-Tool "node"
    Npm       = Get-Tool "npm"
    Pnpm      = Get-Tool "pnpm"
    Yarn      = Get-Tool "yarn"
    Python    = Get-Tool "python"
    Pip       = Get-Tool "pip"
    UV        = Get-Tool "uv"
    Java      = Get-Tool "java" "-version"
    Gradle    = Get-Tool "gradle"
    Maven     = Get-Tool "mvn"
    DotNet    = Get-Tool "dotnet"
    Rustc     = Get-Tool "rustc"
    Cargo     = Get-Tool "cargo"
    Go        = Get-Tool "go" "version"
    Git       = Get-Tool "git"
    Docker    = Get-Tool "docker"
    Kubectl   = Get-Tool "kubectl" "version --client"
    Helm      = Get-Tool "helm"
    Terraform = Get-Tool "terraform" "version"
}
$wslStatus = wsl --status 2>$null
$runtimes.WSL = @{
    Installed = if ($wslStatus) { $true } else { $false }
    Status = "$wslStatus"
}
$runtimes | ConvertTo-Json -Depth 4 | Out-File (Join-Path $outputPath "04_runtimes-toolchains.json") -Encoding UTF8

Write-Host "[5/6] Diretorios criticos"
$critical = @(
    @{ Name = "Desktop"; Path = [Environment]::GetFolderPath("Desktop") },
    @{ Name = "Documents"; Path = [Environment]::GetFolderPath("MyDocuments") },
    @{ Name = "Downloads"; Path = (Join-Path $env:USERPROFILE "Downloads") },
    @{ Name = "Pictures"; Path = [Environment]::GetFolderPath("MyPictures") },
    @{ Name = "AppData_Roaming"; Path = $env:APPDATA },
    @{ Name = "AppData_Local"; Path = $env:LOCALAPPDATA },
    @{ Name = ".ssh"; Path = (Join-Path $env:USERPROFILE ".ssh") },
    @{ Name = ".gnupg"; Path = (Join-Path $env:USERPROFILE ".gnupg") },
    @{ Name = "source"; Path = (Join-Path $env:USERPROFILE "source") },
    @{ Name = "projects"; Path = (Join-Path $env:USERPROFILE "projects") }
)

$dirRows = @()
foreach ($dir in $critical) {
    if (-not $dir.Path -or -not (Test-Path $dir.Path)) {
        $dirRows += [PSCustomObject]@{ Name = $dir.Name; Path = $dir.Path; Exists = $false; SizeGB = 0; FileCount = 0 }
        continue
    }

    $files = Get-ChildItem $dir.Path -File -Recurse -ErrorAction SilentlyContinue
    $size = ($files | Measure-Object -Property Length -Sum).Sum
    $dirRows += [PSCustomObject]@{
        Name = $dir.Name
        Path = $dir.Path
        Exists = $true
        SizeGB = [math]::Round(($size / 1GB), 2)
        FileCount = $files.Count
    }
}
$dirRows | Export-Csv (Join-Path $outputPath "05_critical-dirs.csv") -NoTypeInformation -Encoding UTF8

Write-Host "[6/6] Credenciais/configs (presenca apenas)"
$cred = [ordered]@{
    SSH             = Test-Path (Join-Path $env:USERPROFILE ".ssh")
    GPG             = Test-Path (Join-Path $env:USERPROFILE ".gnupg")
    AWS             = Test-Path (Join-Path $env:USERPROFILE ".aws")
    NPMRC           = Test-Path (Join-Path $env:USERPROFILE ".npmrc")
    DockerConfig    = Test-Path (Join-Path $env:USERPROFILE ".docker\config.json")
    GitConfig       = Test-Path (Join-Path $env:USERPROFILE ".gitconfig")
    VSCodeSettings  = Test-Path (Join-Path $env:APPDATA "Code\User\settings.json")
    CursorSettings  = Test-Path (Join-Path $env:APPDATA "Cursor\User\settings.json")
    WTSettings      = Test-Path (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json")
}
$cred | ConvertTo-Json -Depth 3 | Out-File (Join-Path $outputPath "06_credentials-configs.json") -Encoding UTF8

$index = [ordered]@{
    Timestamp = $timestamp
    OutputPath = $outputPath
    Summary = @{
        TotalApps = @($apps).Count
        PackageManagersDetected = @($pm.Keys).Count
        RuntimesDetected = @($runtimes.GetEnumerator() | Where-Object { $_.Value.Installed -eq $true }).Count
        CriticalDirsScanned = @($dirRows).Count
    }
}
$index | ConvertTo-Json -Depth 5 | Out-File (Join-Path $outputPath "00_INDEX.json") -Encoding UTF8

Write-Host ""
Write-Host "Auditoria concluida: $outputPath" -ForegroundColor Green
Start-Process explorer.exe $outputPath
