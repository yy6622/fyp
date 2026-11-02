@echo off
rem Writes the test toolchain versions to test_results\env_check.txt
cd /d "%~dp0"
if not exist test_results mkdir test_results
(
echo ==== %date% %time%
echo --- java
java -version 2>&1
echo --- node
node -v 2>&1
echo --- firebase
call firebase --version 2>&1
echo --- flutter
call flutter --version 2>&1
echo --- flutter devices
call flutter devices 2>&1
echo --- flutter emulators
call flutter emulators 2>&1
echo ==== done
) > test_results\env_check.txt 2>&1
