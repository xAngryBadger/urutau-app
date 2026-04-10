#Requires -RunAsAdministrator
param(
    [ValidateSet("prep", "restore")]
    [string]$Mode = "prep",
    [string]$DriveLetter = "C:"
)

$ErrorActionPreference = "Continue"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

if ($Mode -eq "prep") {
    Write-Step "Desativando hibernacao (remove hiberfil.sys)"
    powercfg /h off

    Write-Step "Desativando arquivo de paginacao automatico"
    wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False | Out-Null

    $driveEscaped = $DriveLetter.TrimEnd(":") + ":\\"
    Write-Step "Removendo pagefile em $DriveLetter (se existir)"
    wmic pagefileset where name="$driveEscaped`pagefile.sys" delete | Out-Null

    Write-Step "Desativando System Protection (restauracao do sistema)"
    Disable-ComputerRestore -Drive $DriveLetter

    Write-Step "Apagando snapshots (Volume Shadow Copies)"
    vssadmin delete shadows /for=$DriveLetter /all /quiet | Out-Null

    Write-Step "Limpando componentes antigos do Windows (DISM StartComponentCleanup)"
    DISM /Online /Cleanup-Image /StartComponentCleanup | Out-Null

    Write-Step "Consolidando espaco livre (defrag /X)"
    defrag $DriveLetter /X /U /V

    Write-Host ""
    Write-Host "PREP concluido." -ForegroundColor Green
    Write-Host "1) Reinicie o PC AGORA." -ForegroundColor Yellow
    Write-Host "2) Abra diskmgmt.msc e tente diminuir C: novamente." -ForegroundColor Yellow
    Write-Host "3) Quando terminar o shrink, rode este script com -Mode restore." -ForegroundColor Yellow
    exit 0
}

if ($Mode -eq "restore") {
    Write-Step "Reativando gerenciamento automatico do arquivo de paginacao"
    wmic computersystem where name="%computername%" set AutomaticManagedPagefile=True | Out-Null

    Write-Step "Reativando System Protection para C:"
    Enable-ComputerRestore -Drive $DriveLetter

    Write-Step "Reativando hibernacao"
    powercfg /h on

    Write-Host ""
    Write-Host "RESTORE concluido." -ForegroundColor Green
    Write-Host "Recomendado: revisar manualmente em sysdm.cpl (pagefile e protecao do sistema)." -ForegroundColor Yellow
}
