@echo off
setlocal EnableExtensions

REM Run from: AsterionClient\downloads\production-latest
REM 1) Copies newest client-*-all.jar from Asterion client build libs -> client.jar here
REM 2) Writes client.sha256 here
REM 3) Optionally commits and pushes the downloads repo

set "HERE=%~dp0"
set "DOWNLOADS_REPO=%HERE%.."
set "CLIENT_LIBS=%USERPROFILE%\Desktop\Asterion\client\runelite-client\build\libs"

if not exist "%CLIENT_LIBS%" (
    echo ERROR: Client libs folder not found:
    echo   %CLIENT_LIBS%
    echo Build the client first, e.g.:
    echo   cd Desktop\Asterion\client
    echo   gradlew-java21.bat :runelite-client:shadowJar
    pause
    exit /b 1
)

if not exist "%DOWNLOADS_REPO%\.git" (
    echo ERROR: Downloads git repo not found at:
    echo   %DOWNLOADS_REPO%
    pause
    exit /b 1
)

set "SOURCE_JAR="
for /f "delims=" %%F in ('dir /b /a-d /o-d "%CLIENT_LIBS%\*-all.jar" 2^>nul') do (
    set "SOURCE_JAR=%CLIENT_LIBS%\%%F"
    goto :found_jar
)

:found_jar
if not defined SOURCE_JAR (
    echo ERROR: No *-all.jar found in:
    echo   %CLIENT_LIBS%
    echo Run: gradlew-java21.bat :runelite-client:shadowJar
    pause
    exit /b 1
)

echo Source: %SOURCE_JAR%
echo Dest:   %HERE%client.jar
echo.

copy /Y "%SOURCE_JAR%" "%HERE%client.jar" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy client.jar
    pause
    exit /b 1
)

powershell -NoProfile -Command ^
  "(Get-FileHash -LiteralPath '%HERE%client.jar' -Algorithm SHA256).Hash.ToLower() | Set-Content -LiteralPath '%HERE%client.sha256' -NoNewline -Encoding ascii"
if errorlevel 1 (
    echo ERROR: Failed to write client.sha256
    pause
    exit /b 1
)

echo Wrote client.sha256:
type "%HERE%client.sha256"
echo.
echo.

set /p DO_PUSH=Commit and push to GitHub now? [Y/N]: 
if /I not "%DO_PUSH%"=="Y" (
    echo Skipped git push. Files ready in:
    echo   %HERE%
    pause
    exit /b 0
)

where gh >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI ^(gh^) not found.
    echo Install from https://cli.github.com/ then re-run this script.
    pause
    exit /b 1
)

echo.
echo Current GitHub auth:
gh auth status
echo.
set /p DO_SWITCH=Switch / re-auth GitHub account before push? [Y/N]: 
if /I "%DO_SWITCH%"=="Y" (
    echo.
    echo Tip: pick the account that has write access to AsterionRSPS/downloads.
    gh auth login
    if errorlevel 1 (
        echo ERROR: GitHub login failed.
        pause
        exit /b 1
    )
)

REM Make git push use the active gh credentials for github.com
gh auth setup-git
if errorlevel 1 (
    echo ERROR: gh auth setup-git failed.
    pause
    exit /b 1
)

pushd "%DOWNLOADS_REPO%"
git add production-latest/client.jar production-latest/client.sha256
git commit -m "Update production-latest client"
if errorlevel 1 (
    echo Nothing to commit, or commit failed.
) else (
    git push
    if errorlevel 1 (
        echo ERROR: git push failed.
        echo Try answering Y to re-auth next run, or run: gh auth login
        popd
        pause
        exit /b 1
    )
    echo.
    echo Pushed. Restart the Asterion launcher to download the update.
)
popd

echo.
pause
