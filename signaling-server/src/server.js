const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const os = require('os');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Funcion para obtener la IP local (IPv4) de la PC
function getLocalIpAddress() {
  const interfaces = os.networkInterfaces();
  for (const ifaceName of Object.keys(interfaces)) {
    for (const iface of interfaces[ifaceName]) {
      // Filtrar IPv4 y no internas (no 127.0.0.1)
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  return '127.0.0.1';
}

const PORT = process.env.PORT || 3000;
const localIp = getLocalIpAddress();

// Directorio de la aplicacion web compilada (React)
const distPath = path.join(__dirname, '../../web-receiver/dist');

if (fs.existsSync(distPath)) {
  console.log(`[📦] Sirviendo frontend compilado desde: ${distPath}`);
  app.use(express.static(distPath));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/socket.io')) {
      return next();
    }
    res.sendFile(path.join(distPath, 'index.html'));
  });
} else {
  // Página de inicio informativa si aún no se compilo el frontend
  app.get('/', (req, res) => {
    res.send(`
      <!DOCTYPE html>
      <html lang="es">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Screen Mirror - Servidor Activo</title>
        <style>
          body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #f8fafc; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 20px; text-align: center; }
          .card { background: #1e293b; padding: 2.5rem; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); max-width: 550px; border: 1px solid #334155; }
          h1 { color: #38bdf8; margin-bottom: 0.5rem; }
          .badge { display: inline-block; background: #0284c7; color: white; padding: 6px 14px; border-radius: 9999px; font-weight: bold; font-size: 0.9rem; margin-bottom: 1.5rem; }
          .info-box { background: #0f172a; padding: 15px; border-radius: 8px; font-family: monospace; font-size: 1.1rem; color: #4ade80; margin: 15px 0; word-break: break-all; }
          p { color: #94a3b8; line-height: 1.6; }
        </style>
      </head>
      <body>
        <div class="card">
          <h1>🚀 Servidor de Señalización Activo</h1>
          <div class="badge">Screen Mirror WebRTC ($0 Costo)</div>
          <p>El servidor WebSocket está listo para emparejar tu iPhone con la PC o Smart TV.</p>
          <div class="info-box">URL Local: http://${localIp}:${PORT}</div>
          <p>Para cargar el receptor completo con video y código QR, ejecuta el comando de compilación en <code>web-receiver</code> o usa <code>iniciar-servidor.bat</code>.</p>
        </div>
      </body>
      </html>
    `);
  });
}

// Endpoint de informacion para clientes
app.get('/api/info', (req, res) => {
  res.json({
    status: 'online',
    port: PORT,
    localIp: localIp,
    url: `http://${localIp}:${PORT}`,
    activeRooms: Object.keys(rooms).length
  });
});

// Estructura en memoria para salas de emparejamiento
// Formato: { "123456": { windowsId: "socket_id", iphoneId: null, createdAt: timestamp } }
const rooms = {};
let lastPairedRoomCode = null;

// Endpoint para que la extensión de iOS obtenga la sala activa automáticamente
app.get('/api/active-room', (req, res) => {
  let activeCode = (lastPairedRoomCode && rooms[lastPairedRoomCode]) ? lastPairedRoomCode : null;
  if (!activeCode) {
    const roomCodes = Object.keys(rooms);
    if (roomCodes.length > 0) {
      activeCode = roomCodes[roomCodes.length - 1];
    }
  }
  if (activeCode) {
    res.json({
      success: true,
      roomCode: activeCode,
      localIp: localIp,
      port: PORT
    });
  } else {
    res.json({
      success: false,
      message: 'No hay salas abiertas en la PC. Abre el navegador en la PC primero.'
    });
  }
});

// Endpoint para vincular explícitamente el código desde la app principal
app.post('/api/pair', (req, res) => {
  const { roomCode } = req.body || {};
  if (roomCode) {
    lastPairedRoomCode = String(roomCode).trim();
  }
  console.log(`[🔗] iPhone vinculó el código: ${roomCode}`);
  res.json({ success: true, roomCode });
});

io.on('connection', (socket) => {
  const clientIp = socket.handshake.address;
  console.log(`[+] Conexión establecida: ${socket.id} desde ${clientIp}`);

  // 1. Windows o Smart TV genera un código y crea la sala
  socket.on('crear-sala', (codigoSala) => {
    if (!codigoSala || typeof codigoSala !== 'string') return;
    
    // Si la sala existia previamente, la sobreescribimos
    rooms[codigoSala] = {
      windowsId: socket.id,
      iphoneId: null,
      createdAt: Date.now()
    };
    
    socket.join(codigoSala);
    console.log(`[📺] Sala creada: ${codigoSala} (Receptor: ${socket.id})`);
  });

  // 2. iPhone ingresa el código para unirse a la sala
  socket.on('unirse-sala', (codigoSala) => {
    const sala = rooms[codigoSala];
    if (sala && sala.windowsId) {
      sala.iphoneId = socket.id;
      socket.join(codigoSala);
      console.log(`[📱] iPhone ${socket.id} se unió a la sala: ${codigoSala}`);
      
      // Notificar al receptor (Windows/TV) que el iPhone está conectado
      io.to(sala.windowsId).emit('iphone-conectado');
      
      // Confirmar al iPhone que entró con exito
      socket.emit('sala-unida', codigoSala);
    } else {
      socket.emit('error-sala', 'Código de sala inválido o expirado.');
    }
  });

  // 2b. iPhone solicita unirse automáticamente a la sala activa de la PC
  socket.on('unirse-sala-automatica', () => {
    let codigoSala = (lastPairedRoomCode && rooms[lastPairedRoomCode]) ? lastPairedRoomCode : null;
    if (!codigoSala) {
      const roomCodes = Object.keys(rooms);
      if (roomCodes.length > 0) {
        codigoSala = roomCodes[roomCodes.length - 1];
      }
    }
    if (codigoSala && rooms[codigoSala]) {
      const sala = rooms[codigoSala];
      sala.iphoneId = socket.id;
      socket.join(codigoSala);
      console.log(`[📱] iPhone ${socket.id} se unió automáticamente a la sala: ${codigoSala}`);
      io.to(sala.windowsId).emit('iphone-conectado');
      socket.emit('sala-unida', codigoSala);
    } else {
      socket.emit('error-sala', 'No hay salas abiertas en la PC. Abre el navegador primero.');
    }
  });

  // 3. Puente de señalización WebRTC (SDP offer, SDP answer, ICE candidates, reconnect)
  socket.on('mensaje-webrtc', (data) => {
    if (!data || !data.tipo) return;
    let codigo = data.codigo;
    
    // Si no vino código o vino vacío, buscar la sala de este socket
    if (!codigo || !rooms[codigo]) {
      for (const [cod, s] of Object.entries(rooms)) {
        if (s.iphoneId === socket.id || s.windowsId === socket.id) {
          codigo = cod;
          break;
        }
      }
    }
    
    if (codigo && rooms[codigo]) {
      console.log(`[💬] Reenviando ${data.tipo} en sala ${codigo}`);
      socket.to(codigo).emit('mensaje-webrtc', { tipo: data.tipo, payload: data.payload });
    } else {
      console.warn(`[⚠️] Mensaje WebRTC (${data.tipo}) recibido pero no se encontró la sala.`);
    }
  });

  // 4. Manejo de desconexiones
  socket.on('disconnect', (reason) => {
    console.log(`[-] Desconexión: ${socket.id} (Razón: ${reason})`);
    
    for (const [codigo, sala] of Object.entries(rooms)) {
      if (sala.windowsId === socket.id) {
        console.log(`[📺] Receptor desconectado. Cerrando sala ${codigo}`);
        io.to(codigo).emit('peer-desconectado', 'windows');
        delete rooms[codigo];
        break;
      } else if (sala.iphoneId === socket.id) {
        console.log(`[📱] iPhone desconectado de la sala ${codigo}`);
        io.to(codigo).emit('peer-desconectado', 'iphone');
        sala.iphoneId = null; // Permitir reconexión
        break;
      }
    }
  });
});

// Limpieza de salas inactivas cada 30 minutos (antigüedad > 2 horas)
setInterval(() => {
  const now = Date.now();
  const maxAge = 2 * 60 * 60 * 1000;
  for (const [codigo, sala] of Object.entries(rooms)) {
    if (now - sala.createdAt > maxAge) {
      delete rooms[codigo];
      console.log(`[🧹] Sala ${codigo} eliminada por expiración.`);
    }
  }
}, 30 * 60 * 1000);

// Iniciar servidor HTTP y WebSocket
server.listen(PORT, '0.0.0.0', () => {
  console.log('====================================================');
  console.log('  🚀 SCREEN MIRROR SERVER ($0 COSTO) ACTIVO');
  console.log('====================================================');
  console.log(`  🏠 En tu PC abre:       http://localhost:${PORT}`);
  console.log(`  📺 En tu Smart TV abre:  http://${localIp}:${PORT}`);
  console.log(`  📱 En tu iPhone conecta: http://${localIp}:${PORT}`);
  console.log('====================================================\n');
});
