@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "DBT_EXE=%SCRIPT_DIR%..\venv\Scripts\dbt.exe"

if not exist "%DBT_EXE%" (
  set "DBT_EXE=%SCRIPT_DIR%..\.venv-snowflake\Scripts\dbt.exe"
)

if not exist "%DBT_EXE%" (
  echo Repo-local dbt executable not found in ".\venv" or ".\.venv-snowflake".
  echo Recreate the virtualenv from the repo root first.
  exit /b 1
)

"%DBT_EXE%" %*
exit /b %ERRORLEVEL%
