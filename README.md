# 📺 Screen Mirroring: iPhone ➔ PC / Smart TV ($0 Costo)

Una solución completa de duplicación de pantalla de baja latencia (P2P WebRTC) desde un iPhone hacia cualquier PC (Windows/Mac/Linux) o Smart TV, **sin pagar suscripciones, sin comprar dispositivos adicionales y sin ingresar tarjetas de crédito**.

---

## 🎯 ¿Cómo funciona?

1. **Receptor Web Universal:** No necesitas instalar nada en tu televisor ni en otras computadoras. Cualquier Smart TV moderna (Samsung, LG, Android TV, Google TV, Roku TV) o PC con navegador web funciona como receptor.
2. **WebRTC P2P:** El video viaja de forma directa entre tu iPhone y la pantalla a través de tu red Wi-Fi local mediante paquetes UDP optimizados.
3. **Hardware H.264 (VideoToolbox):** Aprovecha la aceleración gráfica del procesador del iPhone para mantener 60 FPS con mínimo consumo de batería y sin sobrepasar el límite de 50 MB de RAM de iOS.
4. **Cero Costo:** Utiliza servidores STUN gratuitos de Google y un servidor de señalización local o cloud gratuito sin tarjeta.

---

## 📁 Estructura del Proyecto

```plaintext
proyecto transmitir mati/
├── signaling-server/      # Servidor de emparejamiento (Node.js + Socket.IO)
│   ├── src/server.js      # Manejo de salas, SDP/ICE y host web
│   └── package.json
├── web-receiver/          # Interfaz visual React + Vite (para PC y Smart TV)
│   ├── src/
│   │   ├── components/    # ReceiverView (código gigante, QR, fullscreen, stats)
│   │   ├── webrtc/        # Lógica WebRTC, STUN de Google y métricas
│   │   └── signaling/     # Conexión WebSocket
│   └── package.json
├── ios/                   # Código nativo en Swift / SwiftUI
│   ├── ScreenMirrorApp/       # App de iPhone (interfaz de emparejamiento)
│   ├── ScreenMirrorExtension/ # Extensión ReplayKit de captura global del sistema
│   └── README-IOS-XCODE.md    # Guía para compilar e instalar gratis en tu iPhone
├── shared/protocol/       # Especificación de eventos y mensajes WebSocket
└── iniciar-servidor.bat   # Script para iniciar todo en Windows con un solo clic
```

---

## 🚀 Inicio Rápido (En tu casa / Red Local)

### 1. Iniciar en tu PC (Windows)
Haz doble clic en el archivo **`iniciar-servidor.bat`** (o ejecuta en consola):
```bash
cd signaling-server
npm install
node src/server.js
```
El servidor detectará automáticamente la dirección IP local de tu PC (por ejemplo, `http://192.168.1.50:3000`).

### 2. En tu Smart TV o Compu Receptora
1. Abre el navegador web integrado en la Smart TV (o en cualquier compu).
2. Entra a la dirección que mostró tu PC: `http://<IP-DE-TU-PC>:3000` (ej: `http://192.168.1.50:3000`).
3. Verás en pantalla un **código de 6 dígitos gigante** y un **código QR**.

### 3. En tu iPhone
1. Abre la app **ScreenMirrorApp**.
2. Escribe el código de 6 dígitos que ves en la tele y pulsa **"Guardar y Vincular"**.
3. Toca el botón rojo de transmisión y selecciona **"Iniciar Transmisión"**.
4. ¡Listo! Tu pantalla se duplicará en tiempo real en la tele o compu.

---

## 🌐 Opción Gratuita en la Nube (Transmitir en cualquier lugar del mundo)

Si quieres ir a la casa de un amigo o a una oficina y transmitir en cualquier tele sin tener tu PC encendida:

1. **Deploy del Servidor en Render (100% Gratis y sin tarjeta):**
   - Crea una cuenta gratis en [render.com](https://render.com) (inicia sesión con GitHub).
   - Crea un nuevo **Web Service**, selecciona la carpeta `signaling-server`.
   - Build Command: `npm install`
   - Start Command: `npm start`
   - Render te dará un link público HTTPS gratis (ej: `https://mi-mirror.onrender.com`).
2. **Deploy del Web Receiver en Vercel (100% Gratis y sin tarjeta):**
   - Entra a [vercel.com](https://vercel.com).
   - Importa la carpeta `web-receiver`.
   - En configuración pon que el servidor de señalización apunte a tu URL de Render.
3. ¡Abre esa web en cualquier tele del mundo y transmite directamente!

---

## 🛠️ Opciones y Atajos en Pantalla

- **Pantalla Completa:** Pulsa el botón "Pantalla Completa" o la tecla `F` en el teclado para llenar la tele.
- **Estadísticas WebRTC:** Activa el botón "Estadísticas" para ver FPS, bitrate, jitter y latencia en milisegundos en tiempo real.
- **Ocultamiento Automático:** Los controles y el código desaparecen automáticamente a los 3 segundos de iniciar la transmisión para dejar la imagen 100% limpia.
