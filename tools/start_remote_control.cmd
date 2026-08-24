@echo off
REM ============================================================
REM  출장용 Remote Control 자동 시작
REM
REM  PC가 재부팅돼도 로그인하면 이 창이 자동으로 열리고,
REM  폰(Claude 앱 > Code 탭)에서 이 PC의 세션을 이어받을 수 있다.
REM
REM  이 창은 닫지 말 것. 닫으면 폰에서 세션이 오프라인으로 보인다.
REM  중지하려면 이 창에서 Ctrl+C.
REM
REM  주의: 처음 한 번은 사람이 직접 실행해 (y/n) 확인을 눌러야 한다.
REM        그 확인을 하기 전에는 이 자동 실행도 대기 상태로 멈춘다.
REM ============================================================

title Claude Remote Control - rebalancing_app

cd /d D:\claude_code\rebalancing_app

REM 네트워크가 아직 안 붙은 부팅 직후를 대비해 잠깐 기다린다
timeout /t 25 /nobreak >nul

:loop
echo.
echo [%DATE% %TIME%] Remote Control 시작...
echo.
call "%APPDATA%\npm\claude.cmd" remote-control --name "rebalancing-trip"

REM 서버 모드는 네트워크가 10분 이상 끊기면 스스로 종료된다.
REM 해외에서 되살릴 수 없으므로 여기서 자동으로 다시 띄운다.
echo.
echo [%DATE% %TIME%] 종료됨. 60초 후 다시 시작합니다. (중지: 이 창을 닫기)
timeout /t 60 /nobreak >nul
goto loop
