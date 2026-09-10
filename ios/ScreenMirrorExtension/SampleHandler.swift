import Foundation
import ReplayKit
import WebRTC

/// Controlador principal de la extensión de captura de pantalla.
/// Corre en un proceso separado con límite de 50 MB de RAM.
/// DISEÑO: WebRTC se inicializa en el primer frame (lazy), no en broadcastStarted,
/// para evitar que el RTCPeerConnectionFactory explote la memoria antes de que iOS
/// haya tenido tiempo de asignarle los recursos necesarios.
class SampleHandler: RPBroadcastSampleHandler {

    // MARK: - Configuración
    // URL del servidor hardcodeada como fallback garantizado.
    // Sideloadly con cuenta gratuita elimina App Groups, así que
    // UserDefaults(suiteName:) falla silenciosamente → fallback.
    private let hardcodedServerUrl = "http://192.168.1.38:3000"
    private let hardcodedQuality = 0 // Perfil bajo (menor memoria)

    private var serverUrl: String = ""
    private var roomCode: String = ""
    private var qualityProfile: Int = 0

    // MARK: - Estado lazy
    private var webRTCManager: WebRTCManager?
    private var socketClient: SignalingSocketClient?
    private var isWebRTCStarted = false
    private var frameCount = 0

    // MARK: - Lifecycle

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        NSLog("▶️ [Extension] broadcastStarted invocado.")

        // Leer configuración — puede ser vacío si App Groups fue desactivado por Sideloadly
        let defaults = UserDefaults.standard
        let urlFromApp = defaults.string(forKey: "serverUrl") ?? ""
        let codeFromApp = defaults.string(forKey: "codigoSalaCompartido") ?? ""

        // Usar hardcoded URL como fallback si App Groups no funciona
        serverUrl = urlFromApp.isEmpty ? hardcodedServerUrl : urlFromApp
        roomCode = codeFromApp
        qualityProfile = defaults.integer(forKey: "qualityProfile")

        NSLog("[Extension] Servidor: \(serverUrl) | Sala: '\(roomCode)'")

        // NO inicializar WebRTC aquí — demasiado pesado para los primeros milisegundos.
        // Se inicializa en el primer processSampleBuffer.
    }

    override func broadcastPaused() {
        NSLog("⏸️ [Extension] Pausado.")
    }

    override func broadcastResumed() {
        NSLog("▶️ [Extension] Reanudado.")
    }

    override func broadcastFinished() {
        NSLog("⏹️ [Extension] Finalizado.")
        cleanup()
    }

    // MARK: - Procesamiento de frames

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }

        frameCount += 1

        // Inicializar WebRTC en el frame 5 (dar tiempo al sistema, no al 1 para evitar OOM burst)
        if frameCount == 5 && !isWebRTCStarted {
            isWebRTCStarted = true
            iniciarWebRTC()
        }

        // Enviar frame si WebRTC ya está listo
        if isWebRTCStarted, let manager = webRTCManager {
            manager.capturer.capturarFrameDeReplayKit(sampleBuffer)
        }
    }

    // MARK: - Inicialización lazy de WebRTC y señalización

    private func iniciarWebRTC() {
        NSLog("[Extension] Inicializando WebRTC (lazy, frame 5)...")

        // Crear WebRTCManager
        let manager = WebRTCManager()
        manager.delegate = self
        self.webRTCManager = manager

        // Conectar socket — luego en signalingSocketDidConnect se creará el PeerConnection
        if !roomCode.isEmpty {
            conectarSocket(codigo: roomCode)
        } else {
            // Sin sala guardada: consultar servidor para auto-emparejar
            consultarSalaActivaYConectar()
        }
    }

    private func conectarSocket(codigo: String) {
        self.roomCode = codigo
        NSLog("[Extension] Conectando socket a \(serverUrl) con sala: '\(roomCode)'")
        let client = SignalingSocketClient(serverUrl: serverUrl, roomCode: roomCode)
        client.delegate = self
        self.socketClient = client
        client.connect()
    }

    private func consultarSalaActivaYConectar() {
        guard let url = URL(string: "\(serverUrl)/api/active-room") else {
            conectarSocket(codigo: "")
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self else { return }
            var codigo = ""
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let code = json["roomCode"] as? String {
                codigo = code
                NSLog("[Extension] Sala activa detectada: \(code)")
            }
            self.conectarSocket(codigo: codigo)
        }.resume()
    }

    // MARK: - Limpieza

    private func cleanup() {
        socketClient?.disconnect()
        socketClient = nil
        webRTCManager?.close()
        webRTCManager = nil
        isWebRTCStarted = false
        frameCount = 0
    }
}

// MARK: - WebRTCManagerDelegate

extension SampleHandler: WebRTCManagerDelegate {
    func webRTCManager(_ manager: WebRTCManager, didGenerateSDPOffer sdp: String) {
        socketClient?.sendSDPOffer(sdp: sdp)
    }

    func webRTCManager(_ manager: WebRTCManager, didGenerateICECandidate candidate: RTCIceCandidate) {
        socketClient?.sendICECandidate(
            sdp: candidate.sdp,
            sdpMLineIndex: candidate.sdpMLineIndex,
            sdpMid: candidate.sdpMid
        )
    }

    func webRTCManager(_ manager: WebRTCManager, didChangeIceConnectionState state: RTCIceConnectionState) {
        NSLog("[Extension] ICE state: \(state.rawValue)")
    }
}

// MARK: - SignalingSocketDelegate

extension SampleHandler: SignalingSocketDelegate {
    func signalingSocketDidConnect(_ client: SignalingSocketClient) {
        self.roomCode = client.roomCode
        NSLog("[Extension] Sala confirmada: '\(self.roomCode)'. Iniciando PeerConnection...")
        webRTCManager?.startPeerConnection(qualityProfile: qualityProfile)
        webRTCManager?.createAndSendOffer()
    }

    func signalingSocket(_ client: SignalingSocketClient, didReceiveAnswer sdp: String) {
        NSLog("[Extension] SDP Answer recibida.")
        webRTCManager?.setRemoteAnswer(sdpString: sdp)
    }

    func signalingSocket(_ client: SignalingSocketClient, didReceiveCandidate sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
        webRTCManager?.addRemoteCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
    }

    func signalingSocketDidRequestReconnect(_ client: SignalingSocketClient) {
        NSLog("[Extension] Reconexión solicitada.")
        webRTCManager?.close()
        webRTCManager?.startPeerConnection(qualityProfile: qualityProfile)
        webRTCManager?.createAndSendOffer()
    }

    func signalingSocket(_ client: SignalingSocketClient, didFailWithError message: String) {
        NSLog("[Extension] Error señalización: \(message)")
        // No llamar finishBroadcastWithError para no cortar el broadcast por errores de red
    }

    func signalingSocketDidDisconnect(_ client: SignalingSocketClient) {
        NSLog("[Extension] Socket desconectado.")
    }
}
