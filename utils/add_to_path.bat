@echo off

rem goto :make_path_bak
rem goto :resotre_path

setlocal enableDelayedExpansion
call :get_parent_dir pts_dir %~dp0
set pts_bin_dir=%pts_dir%bin
rem echo %pts_bin_dir%

where /Q pts
if errorlevel 1 (
  path !PATH!%pts_bin_dir%
  call :add_to_user_path "%pts_bin_dir%"
) else (
  echo PTS already in PATH
)
endlocal & set PATH=%PATH%
goto :eof


rem call :get_parent_dir out_var "path"
rem sets out_var=parent_directory_path
:get_parent_dir
if "%~2" == "" exit /b 1
setlocal enableDelayedExpansion
  call :is_abs_path "%~2"
if errorlevel 1 (
  call :_get_parent_dir par_dir "\%~2"
  set par_dir=!par_dir:~3!
) else (
  call :_get_parent_dir par_dir "%~2"
)
endlocal & set %1=%par_dir%
rem call :trim_trailing_slash %1
exit /b 0

:_get_parent_dir
setlocal
set dir=%~2
if .%dir:~-1% == .\ (
  call :get_parent_dir par_dir "%dir:~0,-1%"
) else set par_dir=%~dp2
endlocal & set %1=%par_dir%
exit /b 0

rem call :is_abs_path "path"
rem sets errorlevel 0 if path is absolute
:is_abs_path
if "%~1" == "%~dpn1" exit /b 0
exit /b 1


:resotre_path
for /F "skip=2Tokens=1-2*" %%A in ('Reg Query HKCU\Environment /V path_bak 2^>nul') do set user_path=%%C
setx path "%user_path%"
exit /b 0

:make_path_bak
for /F "skip=2Tokens=1-2*" %%A in ('Reg Query HKCU\Environment /V path 2^>nul') do set user_path=%%C
setx path_bak "%user_path%"
exit /b 0

:: call :add_to_user_path "%a new path"
:add_to_user_path
for /F "skip=2Tokens=1-2*" %%A in ('Reg Query HKCU\Environment /V path 2^>nul') do set user_path=%%C
if not "!user_path:%~1;=!" == "%user_path%" (echo already added& exit /b 0)
setx path "%user_path%%~1;"
echo successfully added
exit /b 0

:: call :remove_from_user_path "%a path to remove"
:remove_from_user_path
for /F "skip=2Tokens=1-2*" %%A in ('Reg Query HKCU\Environment /V path 2^>nul') do set user_path=%%C
if "!user_path:%~1;=!" == "%user_path%" (echo nothing to remove& exit /b 0)
setx path "!user_path:%~1;=!"
echo successfully removed
exit /b 0
