@echo off
cd bin
if "%1"=="debug" (
  :: run debug
  KontentumNC-Debug.exe
) else (
  :: run release
  KontentumNC.exe
)
pause