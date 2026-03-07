@echo off
setlocal
set SCRIPT_DIR=%~dp0
python "%SCRIPT_DIR%generate_whoneeds_data.py" %*
endlocal
