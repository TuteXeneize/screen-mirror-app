@echo off
title Habilitar Puerto 3000 en Firewall de Windows

echo ========================================================
echo   CONFIGURANDO FIREWALL DE WINDOWS PARA SCREEN MIRROR
echo ========================================================
echo.

netsh advfirewall firewall add rule name="ScreenMirror Port 3000" dir=in action=allow protocol=TCP localport=3000 profile=any
netsh advfirewall firewall set rule name="Node.js JavaScript Runtime" new profile=any

echo.
echo ========================================================
echo   [EXITO] Puerto 3000 y Node.js permitidos en tu red!
echo ========================================================
echo.
pause
