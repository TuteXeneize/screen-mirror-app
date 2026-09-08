// Gestor de WebRTC para el Receptor (PC Windows / Smart TV)

export function setupPeerConnection({
  socket,
  roomCode,
  onStreamReceived,
  onStateChange,
  onStatsUpdate
}) {
  let pc = null;
  let statsInterval = null;
  let lastBytesReceived = 0;
  let lastTimestamp = 0;

  function init() {
    if (pc) {
      cleanup();
    }

    pc = new RTCPeerConnection({
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
      ]
    });

    // 1. Escuchar la llegada del track de video desde el iPhone
    pc.ontrack = (event) => {
      console.log('[WebRTC] Track de video recibido:', event.streams);
      if (event.streams && event.streams[0]) {
        onStreamReceived(event.streams[0]);
      }
    };

    // 2. Enviar candidatos ICE generados por el receptor al iPhone
    pc.onicecandidate = (event) => {
      if (event.candidate) {
        socket.emit('mensaje-webrtc', {
          codigo: roomCode,
          tipo: 'ice-candidate',
          payload: event.candidate
        });
      }
    };

    // 3. Monitorear cambios en el estado de la conexión ICE
    pc.oniceconnectionstatechange = () => {
      const state = pc.iceConnectionState;
      console.log('[WebRTC] Estado ICE:', state);
      onStateChange(state);

      if (state === 'connected') {
        startStatsMonitoring();
      } else if (state === 'disconnected' || state === 'failed') {
        stopStatsMonitoring();
        console.warn('[WebRTC] Conexión perdida, solicitando reintento...');
        socket.emit('mensaje-webrtc', {
          codigo: roomCode,
          tipo: 'reconnect-request',
          payload: null
        });
      }
    };
  }

  // Escuchar mensajes de señalización provenientes del iPhone
  const handleSignalingMessage = async (data) => {
    if (!data || !pc) return;

    try {
      if (data.tipo === 'offer') {
        console.log('[WebRTC] Oferta SDP recibida del iPhone');
        await pc.setRemoteDescription(new RTCSessionDescription(data.payload));
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        // Enviar respuesta (Answer) al iPhone
        socket.emit('mensaje-webrtc', {
          codigo: roomCode,
          tipo: 'answer',
          payload: answer
        });
        console.log('[WebRTC] Respuesta SDP (Answer) enviada al iPhone');
      } else if (data.tipo === 'ice-candidate' && data.payload) {
        await pc.addIceCandidate(new RTCIceCandidate(data.payload));
      }
    } catch (err) {
      console.error('[WebRTC] Error procesando mensaje de señalización:', err);
    }
  };

  socket.on('mensaje-webrtc', handleSignalingMessage);

  // Monitoreo de métricas en tiempo real con getStats()
  function startStatsMonitoring() {
    stopStatsMonitoring();
    lastBytesReceived = 0;
    lastTimestamp = 0;

    statsInterval = setInterval(async () => {
      if (!pc || pc.iceConnectionState !== 'connected') return;

      try {
        const stats = await pc.getStats();
        let fps = 0;
        let bitrateKbps = 0;
        let packetsLost = 0;
        let jitterMs = 0;
        let rttMs = 0;

        stats.forEach((report) => {
          if (report.type === 'inbound-rtp' && report.kind === 'video') {
            const bytes = report.bytesReceived;
            const now = report.timestamp;

            if (lastTimestamp > 0 && bytes >= lastBytesReceived) {
              const deltaBytes = bytes - lastBytesReceived;
              const deltaTime = now - lastTimestamp;
              if (deltaTime > 0) {
                bitrateKbps = Math.round((deltaBytes * 8) / deltaTime);
              }
            }

            lastBytesReceived = bytes;
            lastTimestamp = now;
            fps = report.framesPerSecond || 0;
            packetsLost = report.packetsLost || 0;
            jitterMs = Math.round((report.jitter || 0) * 1000);
          }

          if (report.type === 'candidate-pair' && report.state === 'succeeded') {
            rttMs = Math.round((report.currentRoundTripTime || 0) * 1000);
          }
        });

        if (onStatsUpdate) {
          onStatsUpdate({ fps, bitrateKbps, packetsLost, jitterMs, rttMs });
        }
      } catch (err) {
        console.error('[WebRTC] Error leyendo getStats:', err);
      }
    }, 1000);
  }

  function stopStatsMonitoring() {
    if (statsInterval) {
      clearInterval(statsInterval);
      statsInterval = null;
    }
  }

  function cleanup() {
    stopStatsMonitoring();
    if (socket) {
      socket.off('mensaje-webrtc', handleSignalingMessage);
    }
    if (pc) {
      pc.close();
      pc = null;
    }
  }

  // Inicializar conexión
  init();

  return {
    cleanup,
    reset: init
  };
}
