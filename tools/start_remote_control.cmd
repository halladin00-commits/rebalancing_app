@echo off
REM ===================================================================
REM  Claude Remote Control - auto start for travel
REM  (Korean notes: tools/REMOTE_CONTROL.md)
REM
REM  Keep this window OPEN. Closing it takes the session offline.
REM  To stop: press Ctrl+C in this window.
REM ===================================================================

title Claude Remote Control - rebalancing_app

cd /d D:\claude_code\rebalancing_app

REM Wait for the network stack after a reboot.
timeout /t 25 /nobreak >nul

:loop
echo.
echo [%DATE% %TIME%] Starting Remote Control ...
echo.
call "%APPDATA%\npm\claude.cmd" remote-control --name "rebalancing-trip"

REM Server mode quits after ~10 min without network. Restart it so the
REM session comes back on its own while nobody is at the machine.
echo.
echo [%DATE% %TIME%] Exited. Restarting in 60s.  (Ctrl+C to stop)
timeout /t 60 /nobreak >nul
goto loop
