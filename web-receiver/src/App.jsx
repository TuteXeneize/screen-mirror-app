import React, { useState, useEffect, useRef } from 'react';
import { createSocketConnection, getSignalingUrl } from './signaling/socketClient';
import { setupPeerConnection } from './webrtc/peerConnection';
import ReceiverView from './components/ReceiverView';

export default function App() {
  const [roomCode, setRoomCode] = useState(() => {
    return Math.floor(100000 + Math.random() * 900000).toString();
  });
  const [connectionState, setConnectionState] = useState('idle'); // 'idle' | 'connecting' | 'connected' | 'disconnected'
  const [stream, setStream] = useState(null);
  const [stats, setStats] = useState(null);
  const [serverUrl, setServerUrl] = useState('');

  const socketRef = useRef(null);
  const webrtcManagerRef = useRef(null);

  // Obtener URL de señalización
  useEffect(() => {
    setServerUrl(getSignalingUrl());
  }, []);

  // Inicializar Socket.IO y WebRTC
  useEffect(() => {
    const socket = createSocketConnection();
    socketRef.current = socket;

    socket.on('connect', () => {
      console.log('[Socket] Conectado con ID:', socket.id);
      socket.emit('crear-sala', roomCode);
      setConnectionState('waiting');
    });

    socket.on('iphone-conectado', () => {
      console.log('[Socket] iPhone detectado. Iniciando negociación...');
      setConnectionState('connecting');
    });

    socket.on('peer-desconectado', (peer) => {
      console.log(`[Socket] Peer desconectado: ${peer}`);
      if (peer === 'iphone') {
        setStream(null);
        setConnectionState('disconnected');
      }
    });

    // Configurar WebRTC PeerConnection
    const webrtc = setupPeerConnection({
      socket,
      roomCode,
      onStreamReceived: (remoteStream) => {
        console.log('[App] Video stream listo para reproducir');
        setStream(remoteStream);
        setConnectionState('connected');
      },
      onStateChange: (state) => {
        if (state === 'connected') {
          setConnectionState('connected');
        } else if (state === 'disconnected' || state === 'failed') {
          setConnectionState('disconnected');
        }
      },
      onStatsUpdate: (currentStats) => {
        setStats(currentStats);
      }
    });

    webrtcManagerRef.current = webrtc;

    return () => {
      webrtc.cleanup();
      socket.disconnect();
    };
  }, [roomCode]);

  // Generar nuevo código de sala
  const handleRefreshCode = () => {
    const newCode = Math.floor(100000 + Math.random() * 900000).toString();
    setStream(null);
    setConnectionState('idle');
    setRoomCode(newCode);
  };

  return (
    <ReceiverView
      roomCode={roomCode}
      serverUrl={serverUrl}
      connectionState={connectionState}
      stream={stream}
      stats={stats}
      onRefreshCode={handleRefreshCode}
    />
  );
}
