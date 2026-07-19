@echo off
setlocal EnableExtensions

REM Publishes the latest client shadow JAR to the downloads repo:
REM   1) Copies client-*-all.jar -> production-latest\client.jar
REM   2) Writes production-latest\client.sha256
REM   3) Commits and pushes (optional)

set "CLIENT_LIBS=%~dp0runelite-client\build\libs"
set "DOWNLOADS_REPO=%USERPROFILE%\Desktop\AsterionClient\downloads"
set "DEST=%DOWNLOADS_REPO%\production-latest"

if not exist "%CLIENT_LIBS%" (
    echo ERROR: Client libs folder not found:
    echo   %CLIENT_LIBS%
    echo Build the client first, e.g.:
    echo   gradlew-java21.bat :runelite-client:shadowJar
    pause
    exit /b 1
)

if not exist "%DOWNLOADS_REPO%\.git" (
    echo ERROR: Downloads repo not found:
    echo   %DOWNLOADS_REPO%
    pause
    exit /b 1
)

REM Pick the newest *-all.jar in libs
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

if not exist "%DEST%" mkdir "%DEST%"

echo Source: %SOURCE_JAR%
echo Dest:   %DEST%\client.jar
echo.

copy /Y "%SOURCE_JAR%" "%DEST%\client.jar" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy client.jar
    pause
    exit /b 1
)

powershell -NoProfile -Command ^
  "(Get-FileHash -LiteralPath '%DEST%\client.jar' -Algorithm SHA256).Hash.ToLower() | Set-Content -LiteralPath '%DEST%\client.sha256' -NoNewline -Encoding ascii"
if errorlevel 1 (
    echo ERROR: Failed to write client.sha256
    pause
    exit /b 1
)

echo Wrote client.sha256:
type "%DEST%\client.sha256"
echo.
echo.

set /p DO_PUSH=Commit and push to GitHub now? [Y/N]: 
if /I not "%DO_PUSH%"=="Y" (
    echo Skipped git push. Files are ready in:
    echo   %DEST%
    pause
    exit /b 0
)

pushd "%DOWNLOADS_REPO%"
git add production-latest/client.jar production-latest/client.sha256
git commit -m "Update production-latest client"
if errorlevel 1 (
    echo Nothing to commit, or commit failed.
) else (
    git push
    if errorlevel 1 (
        echo ERROR: git push failed. Check your GitHub login/permissions.
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
