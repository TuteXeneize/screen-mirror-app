@echo off
title Screen Mirror - Servidor Local

cd /d "%~dp0signaling-server"

echo ========================================================
echo   SCREEN MIRRORING iPHONE -^> COMPU / SMART TV
echo ========================================================
echo.
echo Iniciando servidor de transmision...
echo.

start http://localhost:3000

node src/server.js

pause
