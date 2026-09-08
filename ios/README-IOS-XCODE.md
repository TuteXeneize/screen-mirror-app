# 📱 Guía: Compilar e Instalar en iPhone ($0 Costo con Apple ID Gratuito)

Esta guía te muestra cómo instalar la aplicación y la extensión de captura en tu iPhone personal **sin pagar la cuenta de desarrollador de Apple ($99/año)** y **sin poner ninguna tarjeta**.

---

## Requisitos
- Una computadora con **macOS** (MacBook, Mac mini, iMac, o máquina virtual macOS).
- **Xcode** instalado (se descarga gratis desde la Mac App Store).
- Un cable USB para conectar tu iPhone (o conexión por Wi-Fi una vez emparejado).
- Tu cuenta personal de Apple ID (la misma que usas en tu iPhone o cualquier cuenta gratuita de iCloud).

---

## Paso 1: Crear el Proyecto en Xcode

1. Abre Xcode y selecciona **Create a new Xcode project**.
2. Elige la pestaña **iOS** -> plantilla **App** y pulsa *Next*.
3. Completa los datos:
   - **Product Name:** `ScreenMirrorApp`
   - **Team:** Selecciona tu cuenta personal (`Tu Nombre (Personal Team)`). Si no aparece, ve a *Xcode -> Settings -> Accounts*, presiona el botón `+` y añade tu Apple ID gratuito.
   - **Organization Identifier:** `com.matias` (o el que prefieras).
   - **Interface:** `SwiftUI`
   - **Language:** `Swift`
4. Guarda el proyecto dentro de la carpeta `ios/` de este repositorio.

---

## Paso 2: Agregar el Target de Broadcast Upload Extension

Para que la captura funcione fuera de la app (cuando navegas en YouTube, TikTok, juegos, etc.), iOS exige una **Broadcast Upload Extension**:

1. En Xcode, ve al menú superior: **File** -> **New** -> **Target...**
2. Selecciona **iOS** -> busca y selecciona **Broadcast Upload Extension** y presiona *Next*.
3. Configura el target:
   - **Product Name:** `ScreenMirrorExtension`
   - **Language:** `Swift`
   - Desmarca la opción *"Include UI Extension"* (solo necesitamos la extensión de subida de buffers).
4. Presiona *Finish* y cuando Xcode pregunte si deseas activar el esquema, presiona *Activate*.

---

## Paso 3: Configurar el App Group (Compartir el Código de Sala)

Como la app principal y la extensión corren en procesos separados, usamos un **App Group** para que la extensión sepa a qué sala conectarse:

1. Selecciona el proyecto raíz en la barra izquierda de Xcode.
2. Selecciona el target **ScreenMirrorApp** -> pestaña **Signing & Capabilities**.
3. Presiona el botón **+ Capability** y haz doble clic en **App Groups**.
4. Haz clic en el botón `+` debajo de App Groups y agrega: `group.com.matias.screenmirror`.
5. Ahora selecciona el target **ScreenMirrorExtension** -> pestaña **Signing & Capabilities**.
6. Agrega también la capability **App Groups** y tilda la misma casilla: `group.com.matias.screenmirror`.

---

## Paso 4: Agregar las Librerías Open Source (SPM)

En Xcode, ve a **File** -> **Add Package Dependencies...**:

1. **WebRTC:**
   - URL: `https://github.com/stasel/WebRTC`
   - Dependency Rule: *Up to Next Major Version*
   - Agrégalo tanto al target `ScreenMirrorApp` como al target `ScreenMirrorExtension`.

2. **Socket.IO-Client-Swift:**
   - URL: `https://github.com/socketio/socket.io-client-swift`
   - Dependency Rule: *Up to Next Major Version*
   - Agrégalo al target `ScreenMirrorExtension` (y `ScreenMirrorApp` si deseas).

---

## Paso 5: Reemplazar el Código con los Archivos del Proyecto

Reemplaza los archivos generados automáticamente por los que ya dejamos listos:
- En la carpeta de la App: copia `ContentView.swift`, `ScreenMirrorApp.swift` e `Info.plist`.
- En la carpeta de la Extensión: copia `SampleHandler.swift`, `ReplayKitCapturer.swift`, `WebRTCManager.swift`, `SocketClient.swift` e `Info.plist`.

---

## Paso 6: Compilar e Instalar en tu iPhone

1. Conecta tu iPhone a la Mac con el cable USB.
2. En la barra superior de Xcode, selecciona tu iPhone físico como destino de ejecución.
3. Presiona el botón **Play (▶️)** o `Cmd + R`.
4. La primera vez que instales, iOS bloqueará la apertura por seguridad. En tu iPhone ve a:
   - **Ajustes** -> **General** -> **Gestión de dispositivos y VPN** (o *Condición y desarrollo* en iOS 16+).
   - Toca tu correo de Apple ID y presiona **"Confiar en..."**.
   - En iOS 16+, ve a **Ajustes** -> **Privacidad y Seguridad** -> **Modo de Desarrollador** y actívalo (el iPhone se reiniciará una vez).

¡Listo! Ya tienes la app instalada en tu iPhone para transmitir a cualquier tele o compu.
