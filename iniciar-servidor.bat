@echo off
chcp 65001 > nul
title Screen Mirror - Servidor Local ($0 Costo)

echo ========================================================
echo   🚀 SCREEN MIRRORING iPHONE -^> COMPU / SMART TV
echo ========================================================
echo.

:: Verificar si Node.js esta instalado
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] No se encontro Node.js en tu equipo.
    echo Por favor descargalo gratis desde https://nodejs.org/ e instalalo.
    pause
    exit /b 1
)

:: Paso 1: Instalar dependencias del servidor de señalizacion
echo [1/3] Verificando dependencias del servidor...
cd /d "%~dp0signaling-server"
if not exist "node_modules" (
    echo Instalando paquetes del servidor...
    call npm install
)

:: Paso 2: Compilar el receptor web para Windows y Smart TV
echo [2/3] Verificando receptor web (React)...
cd /d "%~dp0web-receiver"
if not exist "node_modules" (
    echo Instalando paquetes del receptor web...
    call npm install
)

if not exist "dist" (
    echo Compilando interfaz web para navegadores y Smart TV...
    call npm run build
)

:: Paso 3: Iniciar servidor local
echo [3/3] Iniciando servidor de transmision...
cd /d "%~dp0signaling-server"
start http://localhost:3000
echo.
echo Presiona Ctrl+C para detener el servidor cuando termines.
echo.
node src/server.js

pause
