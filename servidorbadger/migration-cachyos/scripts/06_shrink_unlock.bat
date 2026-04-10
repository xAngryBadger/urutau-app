@echo off
set SCRIPT=E:\servidorbadger\migration-cachyos\scripts\06_shrink_unlock.ps1

echo ========================================
echo  Shrink Unlock - Windows C:
echo ========================================
echo 1) Preparar para diminuir (prep)
echo 2) Restaurar configuracoes (restore)
echo ========================================
set /p MODE=Escolha 1 ou 2: 

if "%MODE%"=="1" (
  powershell -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode prep -DriveLetter C:
  goto :eof
)

if "%MODE%"=="2" (
  powershell -ExecutionPolicy Bypass -File "%SCRIPT%" -Mode restore -DriveLetter C:
  goto :eof
)

echo Opcao invalida.
