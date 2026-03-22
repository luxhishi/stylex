@echo off
setlocal

set "ROOT=C:\Users\itsic\Desktop\Work Files\School\Stylex"
subst X: "%ROOT%" >nul 2>&1
set "PATH=%ROOT%\stylex\tools;X:\flutter\bin;%PATH%"
cd /d X:\stylex

echo Stylex shell ready.
echo.
echo You can now run:
echo   flutter --version
echo   flutter clean
echo   flutter pub get
echo   flutter run
echo.

cmd /k
