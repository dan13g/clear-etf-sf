@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "DBT_EXE=%SCRIPT_DIR%..\venv\Scripts\dbt.exe"

if not exist "%DBT_EXE%" (
  echo Repo-local dbt executable not found at "%DBT_EXE%".
  echo Recreate the virtualenv from the repo root first.
  exit /b 1
)

"%DBT_EXE%" %*
exit /b %ERRORLEVEL%
