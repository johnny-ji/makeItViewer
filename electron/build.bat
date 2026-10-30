@echo off
setlocal
set "ELECTRON_BUILDER_NSIS_DIR=%~dp0tools\nsis-3.0.4.1"

if not exist "%ELECTRON_BUILDER_NSIS_DIR%\makensis.exe" (
  echo NSIS is missing. Extract tools\nsis-3.0.4.1.7z to tools\nsis-3.0.4.1 first.
  exit /b 1
)

call npm ci
call npm run dist
