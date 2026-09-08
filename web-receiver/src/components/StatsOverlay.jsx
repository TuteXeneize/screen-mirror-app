import React from 'react';
import { Activity, Gauge, Wifi, AlertTriangle } from 'lucide-react';

export default function StatsOverlay({ stats, visible, onClose }) {
  if (!visible || !stats) return null;

  return (
    <div
      style={{
        position: 'absolute',
        top: '20px',
        right: '20px',
        backgroundColor: 'rgba(15, 23, 42, 0.85)',
        backdropFilter: 'blur(8px)',
        border: '1px solid rgba(56, 189, 248, 0.3)',
        borderRadius: '12px',
        padding: '16px',
        color: '#f8fafc',
        fontFamily: 'monospace',
        fontSize: '0.85rem',
        zIndex: 50,
        boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
        minWidth: '220px',
        pointerEvents: 'auto'
      }}
    >
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '12px',
          borderBottom: '1px solid #334155',
          paddingBottom: '8px'
        }}
      >
        <span style={{ fontWeight: 'bold', color: '#38bdf8', display: 'flex', alignItems: 'center', gap: '6px' }}>
          <Activity size={16} /> Diagnóstico P2P
        </span>
        <button
          onClick={onClose}
          style={{
            background: 'none',
            border: 'none',
            color: '#94a3b8',
            fontSize: '1rem',
            cursor: 'pointer',
            padding: '0 4px'
          }}
        >
          ✕
        </button>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: '#94a3b8' }}>FPS Recibidos:</span>
          <span style={{ fontWeight: 'bold', color: stats.fps > 25 ? '#4ade80' : '#facc15' }}>
            {stats.fps} fps
          </span>
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: '#94a3b8' }}>Bitrate:</span>
          <span style={{ fontWeight: 'bold', color: '#38bdf8' }}>
            {stats.bitrateKbps} kbps
          </span>
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: '#94a3b8' }}>Latencia (RTT):</span>
          <span style={{ fontWeight: 'bold', color: stats.rttMs < 50 ? '#4ade80' : '#f87171' }}>
            {stats.rttMs} ms
          </span>
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: '#94a3b8' }}>Jitter:</span>
          <span style={{ fontWeight: 'bold', color: '#cbd5e1' }}>
            {stats.jitterMs} ms
          </span>
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ color: '#94a3b8' }}>Pérdida paq.:</span>
          <span style={{ fontWeight: 'bold', color: stats.packetsLost === 0 ? '#4ade80' : '#f87171' }}>
            {stats.packetsLost}
          </span>
        </div>
      </div>
    </div>
  );
}
