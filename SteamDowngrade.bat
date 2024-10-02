@echo off
setlocal enabledelayedexpansion

:: Define variables
mkdir "%TEMP%\SteamOldManifestLinks" 2>nul
set "linksFile=%TEMP%\SteamOldManifestLinks\links.txt"
set "repo_owner=SteamDatabase"
set "repo_name=SteamTracking"
set "file_path=ClientManifest/steam_client_win32"
set "steamPath="
set "version="
set "commit_sha="
set "target_date="
set "found_date="

set /p "target_date=Enter the target date, this will look for closest older than the given date (YYYY-MM-DD): "
echo.

:: Call PowerShell code to fetch closest commit SHA
for /f "tokens=1,2 delims=," %%I in ('powershell -ExecutionPolicy Bypass -Command "& {.\fetch_commit.ps1 -RepoOwner '%repo_owner%' -RepoName '%repo_name%' -FilePath '%file_path%' -TargetDate '%target_date%'}"') do (
    set "commit_sha=%%I"
    set "found_date=%%J"
)

rem Check if commit SHA is empty
if "%commit_sha%" == "" (
    echo.
    echo Error: Failed to fetch commit SHA.
    pause
    exit /b 1
) else (
    echo.
    echo Commit SHA: %commit_sha%
    echo Version from date: %found_date%
)

pause

for /f "delims=" %%I in ('powershell.exe -noprofile -command "(new-object -COM 'Shell.Application').BrowseForFolder(0,'Please select the folder containing the required files.',0x200,0).self.path"') do (
        set "steamPath=%%I"
    )
echo Selected Path: %steamPath%

:: Check if the folder path is empty or not specified
if not defined steamPath (
    echo.
    echo Error: No folder path specified.
    pause
    exit /b 1
)

:: Check if the folder path exists
if not exist "%steamPath%\steam.exe" (
    echo.
    echo Error: The specified folder does not contain Steam. Given path: "%steamPath%"
    pause
    exit /b 1
)

pause

:: Define folders to delete contents from
set "folders=bin clientui controller_base dumps friends graphics music package public resource steam steamui tenfoot"

:: Check if Steam is running and terminate it if necessary
echo.
echo Checking if Steam is running...
powershell -Command "Get-Process -Name 'steam' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue"

pause

:: Delete contents from Steam folders
echo.
echo Deleting contents from Steam folders...
for %%f in (%folders%) do (
    echo Deleting contents of "%steamPath%\%%f"
    powershell -Command "Get-ChildItem -Path '%steamPath%\%%f' -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue"
    mkdir "%steamPath%\%%f" >nul 2>&1
)

:: Download manifest file
echo.
echo Downloading manifest file... %commit_sha%
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/SteamDatabase/SteamTracking/%commit_sha%/ClientManifest/steam_client_win32' -OutFile '%steamPath%\package\steam_client_win32'"
if errorlevel 1 (
    echo Failed to download additional file.
    pause
    exit /b 1
)

:: Create a copy with .manifest extension
echo.
echo Creating a copy with .manifest extension...
copy "%steamPath%\package\steam_client_win32" "%steamPath%\package\steam_client_win32.manifest"
if errorlevel 1 (
    echo Failed to create a copy with .manifest extension.
    pause
    exit /b 1
)


:: Get the links from the manifest file
echo.
echo Getting download links from the manifest file...
> "%linksFile%" (
    for /f "usebackq delims=" %%A in ("%steamPath%\package\steam_client_win32") do (
        set "line=%%A"
        echo !line! | findstr /i ".zip." >nul
        if not errorlevel 1 (
            set "file=!line!"
            rem Remove tabs
            set "file=!file:	=!"
            rem Remove "file" and "zipvz" strings
            set "file=!file:"file"=!"
            set "file=!file:"zipvz"=!"
            rem Remove leading and trailing quotes
            set "file=!file:"=!"
            rem Trim leading spaces
            for /f "tokens=* delims= " %%B in ("!file!") do set "file=%%B"
            set "link=https://steamcdn-a.akamaihd.net/client/!file!"
            echo !link!
        )
    )
)

:: Prompt the user for download method
echo.
echo Choose an option:
echo 1. Automatically download package files 
echo 2. Manually specify a folder containing required files

set /p "choice=Enter your choice (1 or 2): "
echo choice is %choice%

if "%choice%"=="1" (
    :: Download packages from links.txt
    echo.
    echo Downloading packages, please wait...
    echo There is no progress bar, so please be patient.
    echo If you want to check just go to Steam\package folder and see if the files are being downloaded.
    powershell -Command "$ErrorActionPreference = 'Stop'; $urls = Get-Content -Path '%linksFile%'; $total = $urls.Count; $jobs = @(); foreach ($url in $urls) { $filename = [System.IO.Path]::GetFileName($url); $outputPath = Join-Path '%steamPath%\package' $filename; $jobs += Start-Job -ScriptBlock { param($url, $outputPath); try { Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop } catch { Write-Error 'Failed to download $url: $_' } } -ArgumentList $url, $outputPath; }; $jobs | Wait-Job; $jobs | Remove-Job" > %TEMP%\SteamOldManifestLinks\logs.txt
    echo Download completed.
) else if "%choice%"=="2" (
    echo.
    echo Select the folder containing required files:
    
    set "folderPath="
    for /f "delims=" %%I in ('powershell.exe -noprofile -command "(new-object -COM 'Shell.Application').BrowseForFolder(0,'Please select the folder containing the required files.',0x200,0).self.path"') do (
        set "folderPath=%%I"
    )
    
    :: Check if the folder path is empty or not specified
    if not defined folderPath (
        echo.
        echo Error: No folder path specified.
        pause
        exit /b 1
    )
    
    :: Check if the folder path exists
    if not exist "!folderPath!\*" (
        echo.
        echo Error: The specified folder does not exist or is empty. Given path: "!folderPath!"
        pause
        exit /b 1
    )

    echo.
    echo Download the files from the links in the links.txt file and place them in the folder you selected. After that continue.
    echo Make sure they are the only files in the folder.
    start "" "%linksFile%"

    pause

    :: Copy files from the specified folder to Steam installation path
    echo.
    echo Copying files from "!folderPath!" to "%steamPath%\package"...
    xcopy "!folderPath!\*" "%steamPath%\package\" /Y /I > nul
    
    :: Check if copying was successful
    if errorlevel 1 (
        echo.
        echo Failed to copy files from "!folderPath!" to "%steamPath%\package".
        pause
        exit /b 1
    )
) else (
    echo.
    echo Invalid choice. Please enter 1 or 2.
    pause
    exit /b 1
)

:: Delete update blocker and .crash to use it for the workaround
if exist "%steamPath%\steam.cfg" (
    del "%steamPath%\steam.cfg"
)

if exist "%steamPath%\.crash" (
    del "%steamPath%\.crash"
)

:: Start Steam
echo.
echo Starting Steam...
start "" "%steamPath%\steam.exe"
echo Please wait for Steam to start properly.

:: Workaround to wait until steam properly starts
:loop
if exist "%steamPath%\.crash" (
    echo.
    echo Creating steam.cfg file...
    echo BootStrapperInhibitAll=Enable > "%steamPath%\steam.cfg"
    echo BootStrapperForceSelfUpdate=disable >> "%steamPath%\steam.cfg"
) else (
    ping -n 1 -w 250 127.0.0.1 > nul
    goto loop
)


del "%linksFile%" 
echo.
echo.
echo All tasks completed successfully.
pause
exit /b 0
