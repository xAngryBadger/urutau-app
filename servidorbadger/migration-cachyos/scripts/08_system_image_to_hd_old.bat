@echo off
echo ==========================================
echo  Backup de Imagem do Windows para HD OLD
echo ==========================================
echo.
echo Este comando cria imagem restauravel em F:\WindowsImageBackup
echo.
echo Execute este .bat como Administrador.
echo.
pause

wbadmin start backup -backupTarget:F: -include:C: -allCritical -quiet

echo.
echo Finalizado. Verifique pasta F:\WindowsImageBackup
pause
