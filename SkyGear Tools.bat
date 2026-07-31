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
REM the way.

setlocal
cd /d "%~dp0skygear-godot"

set "GODOT=%LOCALAPPDATA%\..\..\.local\bin\godot.exe"
if not exist "%GODOT%" set "GODOT=%USERPROFILE%\.local\bin\godot.exe"
if not exist "%GODOT%" set "GODOT=godot"

if "%~1"=="" goto menu

"%GODOT%" --path . --headless --script tools/hub.gd -- %*
echo.
pause
exit /b

:menu
"%GODOT%" --path . --headless --script tools/hub.gd
echo.
set /p PICK=which one?  (or blank to close)
if "%PICK%"=="" exit /b
"%GODOT%" --path . --headless --script tools/hub.gd -- %PICK%
echo.
pause
goto menu
