@echo off
rem Runs only the admin/partner web console tests (Chrome + Firebase emulators). No Android emulator needed.
rem Log: test_results\run_log_web.txt
cd /d "%~dp0"
if not exist test_results mkdir test_results
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_tests.ps1" -Only web > test_results\run_log_web.txt 2>&1
echo ==== finished %date% %time% >> test_results\run_log_web.txt
