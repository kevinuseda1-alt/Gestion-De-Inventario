@echo off
setlocal
cd /d "%~dp0"
sqlcmd -S "localhost\SQLEXPRESS" -E -b -l 15 -i "SQL\INSTALAR_TODO_NUEVA_PC.sql"
if errorlevel 1 (
 echo Instalacion no completada. Si Bike_Store existe, use REPARAR_BASE_EXISTENTE.cmd.
 pause
 exit /b 1
)
echo Instalacion completada. Usuario inicial: josue. Clave inicial: 123456. Cambiela al entrar.
pause
