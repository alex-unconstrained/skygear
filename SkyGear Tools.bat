@echo off
REM One door to every tool in the project.
REM
REM Double-click this and you get the menu. Or pass a name straight through:
REM     "SkyGear Tools.bat" text
REM     "SkyGear Tools.bat" all
REM     "SkyGear Tools.bat" fit
REM
REM The list, what each tool is FOR, and how to run the non-Godot ones all live
REM in skygear-godot/tools/hub.gd. This file only finds Godot and gets out of
REM the way. One dispatcher serves both the argument path and the menu path,
REM because the menu used to hand Python tools to the Godot hub, which
REM (politely) refused them.

setlocal
cd /d "%~dp0skygear-godot"

set "GODOT=%LOCALAPPDATA%\..\..\.local\bin\godot.exe"
if not exist "%GODOT%" set "GODOT=%USERPROFILE%\.local\bin\godot.exe"
if not exist "%GODOT%" set "GODOT=godot"

if "%~1"=="" goto menu

call :dispatch %*
exit /b

:menu
"%GODOT%" --path . --headless --script tools/hub.gd
echo.
set /p PICK=which one?  (or blank to close)
if "%PICK%"=="" exit /b
call :dispatch %PICK%
goto menu

:dispatch
REM The Python tools. Everything else goes to the Godot hub.
if /i "%~1"=="parity" (
  python tools/parity.py --open
  pause
  exit /b
)
REM Every screen, every width, as one page you can actually review. Extra
REM arguments pass straight through, so `screens --tag before` works.
if /i "%~1"=="screens" (
  python tools/screen_review.py %2 %3 %4 %5
  pause
  exit /b
)
if /i "%~1"=="pack" (
  python tools/pack_itch.py
  pause
  exit /b
)
"%GODOT%" --path . --headless --script tools/hub.gd -- %*
echo.
pause
exit /b
