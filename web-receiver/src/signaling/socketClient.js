import { io } from 'socket.io-client';

// Determinar la URL del servidor de señalización de forma inteligente:
// 1. Si se pasó ?server=... en la URL
// 2. Si está corriendo en Vite dev (puerto 5173), apunta al puerto 3000 de la misma máquina
// 3. Si está servido directamente por el backend (producción en puerto 3000 o cloud), usa window.location.origin
export function getSignalingUrl() {
  const params = new URLSearchParams(window.location.search);
  const customServer = params.get('server');
  if (customServer) {
    return customServer;
  }

  const { hostname, protocol, port } = window.location;
  if (port === '5173') {
    return `${protocol}//${hostname}:3000`;
  }
  return window.location.origin;
}

export function createSocketConnection() {
  const url = getSignalingUrl();
  console.log('[Socket] Conectando a servidor de señalización:', url);
  return io(url, {
    autoConnect: true,
    reconnection: true,
    reconnectionAttempts: Infinity,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 5000,
    transports: ['websocket', 'polling']
  });
}
