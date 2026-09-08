import Foundation
import ReplayKit
import WebRTC

/// Controlador principal de la extensión de captura de pantalla de iOS.
/// Se ejecuta en un proceso independiente del sistema operativo con un límite de memoria estricto de 50 MB.
class SampleHandler: RPBroadcastSampleHandler {

    private let appGroupSuite = "group.com.matias.screenmirror"
    
    private var webRTCManager: WebRTCManager?
    private var socketClient: SignalingSocketClient?
    
    private var serverUrl: String = ""
    private var roomCode: String = ""
    private var qualityProfile: Int = 1

    // 1. Invocado cuando el usuario inicia la duplicación de pantalla
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        print("▶️ [Extension] Transmisión iniciada por el usuario.")

        // Leer los datos de configuración guardados por la App Principal vía App Group
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let codigo = defaults.string(forKey: "codigoSalaCompartido"),
              !codigo.isEmpty else {
            let error = NSError(
                domain: "ScreenMirror",
                code: 1001,
                userInfo: [NSLocalizedFailureReasonErrorKey: "No se encontró el código de sala. Abre la app principal y guárdalo primero."]
            )
            finishBroadcastWithError(error)
            return
        }

        self.roomCode = codigo
        self.serverUrl = defaults.string(forKey: "serverUrl") ?? "http://192.168.1.100:3000"
        self.qualityProfile = defaults.integer(forKey: "qualityProfile")

        print("[Extension] Conectando a sala \(roomCode) en \(serverUrl)...")

        // Inicializar motor WebRTC
        self.webRTCManager = WebRTCManager()
        self.webRTCManager?.delegate = self

        // Inicializar cliente de señalización WebSocket
        self.socketClient = SignalingSocketClient(serverUrl: serverUrl, roomCode: roomCode)
        self.socketClient?.delegate = self
        self.socketClient?.connect()
    }

    // 2. Invocado si el usuario pausa la transmisión
    override func broadcastPaused() {
        print("⏸️ [Extension] Transmisión pausada.")
    }

    // 3. Invocado al reanudar
    override func broadcastResumed() {
        print("▶️ [Extension] Transmisión reanudada.")
    }

    // 4. Invocado cuando se detiene la transmisión
    override func broadcastFinished() {
        print("⏹️ [Extension] Transmisión finalizada. Liberando recursos...")
        cleanup()
    }

    // 5. Inyección de cuadros de video generados por el sistema operativo
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            // Inyectar el buffer de pantalla directamente al adaptador zero-copy
            webRTCManager?.capturer.capturarFrameDeReplayKit(sampleBuffer)
            
        case .audioApp:
            // Audio de aplicaciones (ignorado en Fase 0 para preservar el límite de 50 MB)
            break
            
        case .audioMic:
            // Audio del micrófono (ignorado en MVP)
            break
            
        @unknown default:
            break
        }
    }

    private func cleanup() {
        webRTCManager?.close()
        webRTCManager = nil
        socketClient?.disconnect()
        socketClient = nil
    }
}

// MARK: - WebRTCManagerDelegate
extension SampleHandler: WebRTCManagerDelegate {
    func webRTCManager(_ manager: WebRTCManager, didGenerateSDPOffer sdp: String) {
        // Enviar la oferta SDP local al receptor mediante el WebSocket
        socketClient?.sendSDPOffer(sdp: sdp)
    }

    func webRTCManager(_ manager: WebRTCManager, didGenerateICECandidate candidate: RTCIceCandidate) {
        // Enviar candidatos ICE locales al receptor
        socketClient?.sendICECandidate(
            sdp: candidate.sdp,
            sdpMLineIndex: candidate.sdpMLineIndex,
            sdpMid: candidate.sdpMid
        )
    }

    func webRTCManager(_ manager: WebRTCManager, didChangeIceConnectionState state: RTCIceConnectionState) {
        print("[Extension] Estado ICE de WebRTC: \(state.rawValue)")
    }
}

// MARK: - SignalingSocketDelegate
extension SampleHandler: SignalingSocketDelegate {
    func signalingSocketDidConnect(_ client: SignalingSocketClient) {
        print("[Extension] Socket conectado a sala \(roomCode). Iniciando WebRTC PeerConnection...")
        webRTCManager?.startPeerConnection(qualityProfile: qualityProfile)
        webRTCManager?.createAndSendOffer()
    }

    func signalingSocket(_ client: SignalingSocketClient, didReceiveAnswer sdp: String) {
        print("[Extension] SDP Answer recibida del receptor. Inyectando en WebRTC...")
        webRTCManager?.setRemoteAnswer(sdpString: sdp)
    }

    func signalingSocket(_ client: SignalingSocketClient, didReceiveCandidate sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
        webRTCManager?.addRemoteCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
    }

    func signalingSocketDidRequestReconnect(_ client: SignalingSocketClient) {
        print("[Extension] Petición de reconexión recibida. Reiniciando negociación WebRTC...")
        webRTCManager?.close()
        webRTCManager?.startPeerConnection(qualityProfile: qualityProfile)
        webRTCManager?.createAndSendOffer()
    }

    func signalingSocket(_ client: SignalingSocketClient, didFailWithError message: String) {
        print("[Extension] Error en señalización: \(message)")
        let error = NSError(domain: "ScreenMirrorSignaling", code: 1002, userInfo: [NSLocalizedFailureReasonErrorKey: message])
        finishBroadcastWithError(error)
    }

    func signalingSocketDidDisconnect(_ client: SignalingSocketClient) {
        print("[Extension] Servidor de señalización desconectado.")
    }
}
