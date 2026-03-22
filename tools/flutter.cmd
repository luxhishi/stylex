@echo off
setlocal

set "ROOT=C:\Users\itsic\Desktop\Work Files\School\Stylex"
set "APP=%ROOT%\stylex"
set "SDK_DRIVE=X:"
set "SDK=%SDK_DRIVE%\flutter\bin\flutter.bat"
set "CURRENT=%CD%"

subst %SDK_DRIVE% "%ROOT%" >nul 2>&1

if /I "%CURRENT:~0,43%"=="C:\Users\itsic\Desktop\Work Files\School\Stylex" (
  set "CURRENT=%CURRENT:C:\Users\itsic\Desktop\Work Files\School\Stylex=X:%"
)

if not exist "%CURRENT%" (
  set "CURRENT=X:\stylex"
)

pushd "%CURRENT%"
call "%SDK%" %*
set "ERR=%ERRORLEVEL%"
popd

exit /b %ERR%
