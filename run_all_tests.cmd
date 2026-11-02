@echo off
rem Runs run_tests.ps1 and saves the full console output to test_results\run_log.txt
cd /d "%~dp0"
if not exist test_results mkdir test_results
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_tests.ps1" %* > test_results\run_log.txt 2>&1
echo ==== finished %date% %time% >> test_results\run_log.txt
