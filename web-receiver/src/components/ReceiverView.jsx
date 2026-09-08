import React, { useState, useEffect, useRef } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { Maximize, Minimize, Activity, RefreshCw, Smartphone, Tv, CheckCircle, WifiOff } from 'lucide-react';
import StatsOverlay from './StatsOverlay';

export default function ReceiverView({
  roomCode,
  serverUrl,
  connectionState,
  stream,
  stats,
  onRefreshCode
}) {
  const videoRef = useRef(null);
  const containerRef = useRef(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [showStats, setShowStats] = useState(false);
  const [showControls, setShowControls] = useState(true);
  const hideControlsTimer = useRef(null);

  // Vincular stream de video a la etiqueta <video> cuando llega
  useEffect(() => {
    if (videoRef.current && stream) {
      videoRef.current.srcObject = stream;
      videoRef.current.play().catch((err) => {
        console.warn('[Video] Reproducción automática bloqueada o en espera:', err);
      });
    }
  }, [stream]);

  // Manejar el toggle de pantalla completa
  const toggleFullscreen = () => {
    if (!document.fullscreenElement) {
      containerRef.current?.requestFullscreen?.().catch((err) => {
        console.error('Error al entrar en pantalla completa:', err);
      });
      setIsFullscreen(true);
    } else {
      document.exitFullscreen?.().catch(() => {});
      setIsFullscreen(false);
    }
  };

  // Escuchar cambio de estado de fullscreen nativo
  useEffect(() => {
    const handleFsChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener('fullscreenchange', handleFsChange);
    return () => document.removeEventListener('fullscreenchange', handleFsChange);
  }, []);

  // Ocultar controles flotantes tras inactividad del cursor cuando hay video activo
  const handleMouseMove = () => {
    setShowControls(true);
    if (hideControlsTimer.current) clearTimeout(hideControlsTimer.current);
    if (stream) {
      hideControlsTimer.current = setTimeout(() => {
        setShowControls(false);
      }, 3500);
    }
  };

  // Generar URL para el QR (para escanear y autocompletar en el iPhone)
  const qrData = `${serverUrl}?room=${roomCode}`;

  return (
    <div
      ref={containerRef}
      onMouseMove={handleMouseMove}
      style={{
        width: '100vw',
        height: '100vh',
        backgroundColor: '#020617',
        color: '#f8fafc',
        display: 'flex',
        flexDirection: 'column',
        position: 'relative',
        overflow: 'hidden'
      }}
    >
      {/* 1. Barra de Controles Superior Flotante */}
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '16px 24px',
          background: stream
            ? 'linear-gradient(to bottom, rgba(2, 6, 23, 0.8), transparent)'
            : 'transparent',
          zIndex: 40,
          opacity: showControls || !stream ? 1 : 0,
          transition: 'opacity 0.4s ease',
          pointerEvents: showControls || !stream ? 'auto' : 'none'
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              backgroundColor: '#1e293b',
              padding: '6px 14px',
              borderRadius: '9999px',
              fontSize: '0.9rem',
              border: '1px solid #334155'
            }}
          >
            <div
              style={{
                width: '10px',
                height: '10px',
                borderRadius: '50%',
                backgroundColor:
                  connectionState === 'connected'
                    ? '#22c55e'
                    : connectionState === 'connecting'
                    ? '#eab308'
                    : '#64748b'
              }}
            />
            <span style={{ color: '#cbd5e1' }}>
              {connectionState === 'connected'
                ? 'Transmitiendo en Vivo'
                : connectionState === 'connecting'
                ? 'Negociando WebRTC...'
                : 'Listo para conectar'}
            </span>
          </div>

          {stream && (
            <span style={{ fontSize: '0.85rem', color: '#94a3b8' }}>
              Sala: <strong style={{ color: '#38bdf8' }}>{roomCode}</strong>
            </span>
          )}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          {stream && (
            <button
              onClick={() => setShowStats(!showStats)}
              title="Ver métricas WebRTC"
              style={{
                backgroundColor: showStats ? '#0284c7' : '#1e293b',
                color: '#ffffff',
                border: '1px solid #334155',
                padding: '8px 12px',
                borderRadius: '8px',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                fontSize: '0.85rem'
              }}
            >
              <Activity size={16} /> Estadísticas
            </button>
          )}

          {!stream && (
            <button
              onClick={onRefreshCode}
              title="Generar nuevo código"
              style={{
                backgroundColor: '#1e293b',
                color: '#94a3b8',
                border: '1px solid #334155',
                padding: '8px 12px',
                borderRadius: '8px',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                fontSize: '0.85rem'
              }}
            >
              <RefreshCw size={16} /> Nuevo Código
            </button>
          )}

          <button
            onClick={toggleFullscreen}
            title={isFullscreen ? 'Salir de pantalla completa' : 'Pantalla completa'}
            style={{
              backgroundColor: '#1e293b',
              color: '#ffffff',
              border: '1px solid #334155',
              padding: '8px 12px',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              fontSize: '0.85rem'
            }}
          >
            {isFullscreen ? <Minimize size={16} /> : <Maximize size={16} />}
            {isFullscreen ? 'Salir' : 'Pantalla Completa'}
          </button>
        </div>
      </div>

      {/* 2. Pantalla de Espera / Emparejamiento (10-Foot UI para Smart TV y PC) */}
      {!stream && (
        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
            padding: '40px 20px',
            textAlign: 'center',
            zIndex: 10
          }}
        >
          <div
            style={{
              backgroundColor: '#0f172a',
              border: '1px solid #1e293b',
              borderRadius: '24px',
              padding: '40px 50px',
              maxWidth: '720px',
              width: '90%',
              boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.7)'
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'center', gap: '16px', marginBottom: '16px' }}>
              <Tv size={42} color="#38bdf8" />
              <span style={{ fontSize: '2rem', color: '#475569' }}>➔</span>
              <Smartphone size={42} color="#4ade80" />
            </div>

            <h1 style={{ fontSize: '2.4rem', fontWeight: 800, marginBottom: '8px', color: '#ffffff' }}>
              Duplicar Pantalla iPhone
            </h1>
            <p style={{ color: '#94a3b8', fontSize: '1.2rem', marginBottom: '32px' }}>
              Abre la app en tu iPhone e ingresa este código o escanea el QR
            </p>

            <div
              style={{
                display: 'flex',
                flexWrap: 'wrap',
                justifyContent: 'center',
                alignItems: 'center',
                gap: '40px',
                marginBottom: '32px'
              }}
            >
              {/* Código Gigante de 6 Dígitos */}
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <span style={{ fontSize: '0.9rem', textTransform: 'uppercase', color: '#64748b', letterSpacing: '2px', marginBottom: '8px' }}>
                  Código de Emparejamiento
                </span>
                <div
                  className="code-glow"
                  style={{
                    fontSize: '4.2rem',
                    fontWeight: 900,
                    letterSpacing: '12px',
                    color: '#38bdf8',
                    backgroundColor: '#1e293b',
                    padding: '16px 36px',
                    borderRadius: '16px',
                    border: '2px solid #0284c7',
                    fontFamily: 'monospace'
                  }}
                >
                  {roomCode}
                </div>
              </div>

              {/* Código QR Inteligente */}
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  backgroundColor: '#ffffff',
                  padding: '16px',
                  borderRadius: '16px',
                  boxShadow: '0 10px 25px rgba(0,0,0,0.4)'
                }}
              >
                <QRCodeSVG value={qrData} size={150} level="M" />
                <span style={{ color: '#0f172a', fontSize: '0.75rem', fontWeight: 'bold', marginTop: '8px' }}>
                  Escanear con iPhone
                </span>
              </div>
            </div>

            {/* Pasos explicativos rápidos */}
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-around',
                borderTop: '1px solid #1e293b',
                paddingTop: '24px',
                color: '#94a3b8',
                fontSize: '0.95rem',
                textAlign: 'left',
                gap: '16px'
              }}
            >
              <div>
                <strong style={{ color: '#f1f5f9' }}>1. Mismo Wi-Fi:</strong>
                <br />Verifica que tu iPhone esté en la misma red local.
              </div>
              <div>
                <strong style={{ color: '#f1f5f9' }}>2. Escribe el Código:</strong>
                <br />En la app pulsa Conectar y Transmitir.
              </div>
              <div>
                <strong style={{ color: '#f1f5f9' }}>3. ¡Listo!:</strong>
                <br />Tu pantalla se verá aquí a 60 FPS sin demora.
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 3. Reproductor de Video Transmitido */}
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'contain',
          backgroundColor: '#000000',
          display: stream ? 'block' : 'none'
        }}
      />

      {/* 4. Overlay de Métricas Técnicas WebRTC */}
      <StatsOverlay stats={stats} visible={showStats && !!stream} onClose={() => setShowStats(false)} />
    </div>
  );
}
