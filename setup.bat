@ECHO OFF

set download_uri_python=https://www.python.org/ftp/python/3.11.7/python-3.11.7-amd64.exe
set installer_name_python=python_installer.exe
set download_uri_winget=https://github.com/microsoft/winget-cli/releases/download/v1.6.3482/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
set installer_name_winget=winget_installer.msixbundle
set download_uri_vcredist=https://aka.ms/vs/17/release/vc_redist.x64.exe
set installer_name_vcredist=vcredist_installer.exe

set workspace=C:\workspace
set repo_uri=https://bitbucket.sinc.co.kr/scm/saiv/vims.git
set repo_name=vims
set repo_branch=feature/code_integration
set venv_name=venv

@REM 1. Python ------------------------------------------------------------------------------
echo Installing Python ... -------------------------------------
:check_python
python --version
IF NOT errorlevel 1 (
    echo Python is already installed.
    goto :end_python
)

:install_python
powershell.exe (New-Object System.Net.WebClient).DownloadFile('%download_uri_python%', '%installer_name_python%')
%installer_name_python% /quiet InstallAllUsers=1 PrependPath=1

:end_python
echo -----------------------------------------------------------
echo:
echo:
@REM ----------------------------------------------------------------------------------------

@REM 2. Winget ------------------------------------------------------------------------------
echo Installing winget ... -------------------------------------

:check_winget
powershell winget --version
IF NOT errorlevel 1 (
    echo Winget is already installed.
    goto :end_winget
)

:intall_winget
powershell (New-Object System.Net.WebClient).DownloadFile('%download_uri_winget%', '%installer_name_winget%')
powershell Add-AppxPackage %installer_name_winget%
call :refresh_env

:end_winget
echo -----------------------------------------------------------
echo:
echo:
@REM ----------------------------------------------------------------------------------------

@REM 3. Git ---------------------------------------------------------------------------------
echo Installing Git ... ----------------------------------------

:check_git
git --version
IF NOT errorlevel 1 (
    echo Git is already installed.
    goto :end_git
)

:intall_git
powershell.exe winget install --id Git.Git -e --source winget
call :refresh_env

:end_git
echo -----------------------------------------------------------
echo:
echo:
@REM ----------------------------------------------------------------------------------------

@REM 4. Clone repositary --------------------------------------------------------------------
echo Clone repositary ... --------------------------------------
IF EXIST EXIST %workspace%\%repo_name%\.git (
    echo Repositary already exists
    goto :end_clone
)

IF NOT EXIST %workspace%\%repo_name% (
    echo Create directory - %workspace%\%repo_name%
    mkdir %workspace%\%repo_name%
) ELSE (
    echo %workspace%\%repo_name% already exists.
    rmdir /S /Q %workspace%\%repo_name%
    mkdir %workspace%\%repo_name%
)

git clone -b %repo_branch% %repo_uri% %workspace%\%repo_name%

:end_clone
echo -----------------------------------------------------------
echo:
echo:
@REM ----------------------------------------------------------------------------------------

@REM 5. Set venv ----------------------------------------------------------------------------
echo Set venv ... ----------------------------------------------
IF EXIST %workspace%\%repo_name%\%venv_name% (
    echo venv already exists
    goto :end_venv
)
python -m venv %workspace%\%repo_name%\%venv_name%
%workspace%\%repo_name%\%venv_name%\Scripts\pip install -r %workspace%\%repo_name%\requirements.txt

:end_venv
echo -----------------------------------------------------------
echo:
echo:
@REM ----------------------------------------------------------------------------------------

@REM 99. VCRedist ----------------------------------------------------------------------------
echo Installing Visual C++ Redistributable ... -----------------
%workspace%\%repo_name%\%venv_name%\Scripts\python -c "import torch; print(torch.__version__)"
IF NOT errorlevel 1 (
    echo Pytorch successfully works.
    goto :end_vcredist
)

:install_vcredist
powershell (New-Object System.Net.WebClient).DownloadFile('%download_uri_vcredist%', '%installer_name_vcredist%')
%installer_name_vcredist% /Q

:end_vcredist
echo -----------------------------------------------------------
echo:
echo:
@REM ----------------------------------------------------------------------------------------

echo All dependencies are successfully installed...!
pause

:refresh_env
echo Refresh environment variables ...
goto main

:: Set one environment variable from registry key
:SetFromReg
"%WinDir%\System32\Reg" QUERY "%~1" /v "%~2" > "%TEMP%\_envset.tmp" 2>NUL
for /f "usebackq skip=2 tokens=2,*" %%A IN ("%TEMP%\_envset.tmp") do (
    echo/set "%~3=%%B"
)
goto :EOF

:: Get a list of environment variables from registry
:GetRegEnv
"%WinDir%\System32\Reg" QUERY "%~1" > "%TEMP%\_envget.tmp"
for /f "usebackq skip=2" %%A IN ("%TEMP%\_envget.tmp") do (
    if /I not "%%~A"=="Path" (
        call :SetFromReg "%~1" "%%~A" "%%~A"
    )
)
goto :EOF

:main
echo/@echo off >"%TEMP%\_env.cmd"

:: Slowly generating final file
call :GetRegEnv "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" >> "%TEMP%\_env.cmd"
call :GetRegEnv "HKCU\Environment">>"%TEMP%\_env.cmd" >> "%TEMP%\_env.cmd"

:: Special handling for PATH - mix both User and System
call :SetFromReg "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" Path Path_HKLM >> "%TEMP%\_env.cmd"
call :SetFromReg "HKCU\Environment" Path Path_HKCU >> "%TEMP%\_env.cmd"

:: Caution: do not insert space-chars before >> redirection sign
echo/set "Path=%%Path_HKLM%%;%%Path_HKCU%%" >> "%TEMP%\_env.cmd"

:: Cleanup
del /f /q "%TEMP%\_envset.tmp" 2>nul
del /f /q "%TEMP%\_envget.tmp" 2>nul

:: capture user / architecture
SET "OriginalUserName=%USERNAME%"
SET "OriginalArchitecture=%PROCESSOR_ARCHITECTURE%"

:: Set these variables
call "%TEMP%\_env.cmd"

:: Cleanup
del /f /q "%TEMP%\_env.cmd" 2>nul

:: reset user / architecture
SET "USERNAME=%OriginalUserName%"
SET "PROCESSOR_ARCHITECTURE=%OriginalArchitecture%"

echo | set /p dummy="Finished."
echo .