@echo off
rem Runs only the tests that need the Firebase emulators (integration + web).
rem Needs Java 21+ and a running Android emulator. Log: test_results\run_log_emulator.txt
cd /d "%~dp0"
if not exist test_results mkdir test_results
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_tests.ps1" -Only integration,web > test_results\run_log_emulator.txt 2>&1
echo ==== finished %date% %time% >> test_results\run_log_emulator.txt
