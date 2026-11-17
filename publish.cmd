@echo off
REM Double-click this file to publish your edits to https://luobinjie687.github.io/
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\publish.ps1" %*
