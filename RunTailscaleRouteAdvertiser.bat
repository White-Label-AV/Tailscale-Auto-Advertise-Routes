@echo off
echo Tailscale Route Advertiser
echo ========================
echo.
echo This batch file will launch the Tailscale Route Advertiser with administrator privileges.
echo.

:: Check if running as administrator
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

:: If not running as administrator, restart with admin privileges
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    echo.
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: If we get here, we're running as administrator
echo Running with administrator privileges.
echo.
echo Starting Tailscale Route Advertiser...
echo.

:: Run the PowerShell script with bypass execution policy
powershell -ExecutionPolicy Bypass -File "%~dp0TailscaleRouteAdvertiser.ps1"

exit /b
