import Foundation
import WebRTC

protocol WebRTCManagerDelegate: AnyObject {
    func webRTCManager(_ manager: WebRTCManager, didGenerateSDPOffer sdp: String)
    func webRTCManager(_ manager: WebRTCManager, didGenerateICECandidate candidate: RTCIceCandidate)
    func webRTCManager(_ manager: WebRTCManager, didChangeIceConnectionState state: RTCIceConnectionState)
}

class WebRTCManager: NSObject {
    weak var delegate: WebRTCManagerDelegate?

    private var connectionFactory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    private var videoSource: RTCVideoSource!
    private(set) var capturer: ReplayKitCapturer!

    override init() {
        super.init()
        setupPeerConnectionFactory()
    }

    private func setupPeerConnectionFactory() {
        // Inicializar factoria con codificador nativo por hardware de Apple (VideoToolbox H.264)
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        
        self.connectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )

        // Crear origen de video y vincular el capturador ReplayKit
        self.videoSource = connectionFactory.videoSource()
        self.capturer = ReplayKitCapturer(delegate: videoSource)
    }

    func startPeerConnection(qualityProfile: Int = 1) {
        let config = RTCConfiguration()
        let stunServer = RTCIceServer(urlStrings: [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302"
        ])
        config.iceServers = [stunServer]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        
        self.peerConnection = connectionFactory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )

        // Agregar pista de video
        let videoTrack = connectionFactory.videoTrack(with: self.videoSource, trackId: "screen0")
        self.peerConnection?.add(videoTrack, streamIds: ["screen_stream"])

        // Aplicar configuraciones de codificación y prioridad de fluidez (maintainFramerate)
        applyQualityAndDegradation(qualityProfile: qualityProfile)
    }

    private func applyQualityAndDegradation(qualityProfile: Int) {
        guard let sender = self.peerConnection?.senders.first(where: { $0.track?.kind == "video" }) else {
            return
        }

        let parameters = sender.parameters
        // CLAVE DE FLUIDEZ: Priorizar framerate sobre resolución ante caídas de red
        parameters.degradationPreference = .maintainFramerate

        for encoding in parameters.encodings {
            switch qualityProfile {
            case 0: // Perfil Bajo (Ahorro de batería / red inestable)
                encoding.maxBitrateBps = 1_500_000 // 1.5 Mbps
                encoding.maxFramerate = 30
                encoding.scaleResolutionDownBy = 2.0
            case 2: // Perfil Alto (Máxima fidelidad a 60 FPS)
                encoding.maxBitrateBps = 6_000_000 // 6.0 Mbps
                encoding.maxFramerate = 60
                encoding.scaleResolutionDownBy = 1.0
            default: // Perfil Medio (Equilibrio perfecto calidad/latencia)
                encoding.maxBitrateBps = 3_000_000 // 3.0 Mbps
                encoding.maxFramerate = 60
                encoding.scaleResolutionDownBy = 1.0
            }
        }

        sender.parameters = parameters
        print("[WebRTC] Perfil de calidad aplicado: \(qualityProfile)")
    }

    func createAndSendOffer() {
        guard let pc = self.peerConnection else { return }

        // Restricción unidireccional: Solo emitimos video de pantalla, no recibimos nada
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "false",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: nil
        )

        pc.offer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self, let sdp = sdp, error == nil else {
                print("[WebRTC] Error al generar SDP Offer: \(String(describing: error))")
                return
            }

            pc.setLocalDescription(sdp) { error in
                if let error = error {
                    print("[WebRTC] Error seteando local description: \(error.localizedDescription)")
                } else {
                    print("[WebRTC] SDP Offer local configurada exitosamente.")
                    self.delegate?.webRTCManager(self, didGenerateSDPOffer: sdp.sdp)
                }
            }
        }
    }

    func setRemoteAnswer(sdpString: String) {
        guard let pc = self.peerConnection else { return }
        let remoteDescription = RTCSessionDescription(type: .answer, sdp: sdpString)
        
        pc.setRemoteDescription(remoteDescription) { error in
            if let error = error {
                print("[WebRTC] Error seteando remote answer: \(error.localizedDescription)")
            } else {
                print("[WebRTC] Remote Answer inyectada con éxito. Conexión P2P en curso...")
            }
        }
    }

    func addRemoteCandidate(sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
        guard let pc = self.peerConnection else { return }
        let candidate = RTCIceCandidate(
            sdp: sdp,
            sdpMLineIndex: sdpMLineIndex,
            sdpMid: sdpMid
        )
        
        pc.add(candidate) { error in
            if let error = error {
                print("[WebRTC] Error agregando candidato ICE remoto: \(error.localizedDescription)")
            }
        }
    }

    func close() {
        self.peerConnection?.close()
        self.peerConnection = nil
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.delegate?.webRTCManager(self, didGenerateICECandidate: candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("[WebRTC] Nuevo estado ICE: \(newState.rawValue)")
        self.delegate?.webRTCManager(self, didChangeIceConnectionState: newState)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
