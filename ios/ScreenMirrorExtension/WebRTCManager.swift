import Foundation
import WebRTC

protocol WebRTCManagerDelegate: AnyObject {
    func webRTCManager(_ manager: WebRTCManager, didGenerateSDPOffer sdp: String)
    func webRTCManager(_ manager: WebRTCManager, didGenerateICECandidate candidate: RTCIceCandidate)
    func webRTCManager(_ manager: WebRTCManager, didChangeIceConnectionState state: RTCIceConnectionState)
}

/// Motor WebRTC: solo H.264 por hardware, resolución reducida, sin audio.
class WebRTCManager: NSObject {
    weak var delegate: WebRTCManagerDelegate?

    // Factory compartida (costosa de crear — creada una sola vez)
    private static let sharedFactory: RTCPeerConnectionFactory = {
        // Inicializar globalmente WebRTC — necesario exactamente una vez por proceso
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
    }()

    private var peerConnection: RTCPeerConnection?
    let videoSource: RTCVideoSource
    let capturer: ReplayKitCapturer

    override init() {
        let factory = WebRTCManager.sharedFactory
        videoSource = factory.videoSource(forScreenCast: true)
        capturer = ReplayKitCapturer(delegate: videoSource)
        super.init()
    }

    func startPeerConnection(qualityProfile: Int = 0) {
        let factory = WebRTCManager.sharedFactory

        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302"
        ])]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)

        // Solo video, sin audio
        let videoTrack = factory.videoTrack(with: videoSource, trackId: "screen0")
        peerConnection?.add(videoTrack, streamIds: ["screen"])

        applyEncodingParameters(qualityProfile: qualityProfile)
    }

    private func applyEncodingParameters(qualityProfile: Int) {
        guard let sender = peerConnection?.senders.first(where: { $0.track?.kind == "video" }) else { return }
        let params = sender.parameters
        params.degradationPreference = NSNumber(value: RTCDegradationPreference.maintainFramerate.rawValue)

        for enc in params.encodings {
            // Perfil bajo por defecto — menor consumo de memoria en la extensión
            enc.maxBitrateBps = NSNumber(value: 1_500_000) // 1.5 Mbps
            enc.maxFramerate = NSNumber(value: 30)
            enc.scaleResolutionDownBy = NSNumber(value: 2.0) // Reducir resolución a la mitad
        }
        sender.parameters = params
    }

    func createAndSendOffer() {
        guard let pc = peerConnection else { return }

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "false",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: nil
        )

        pc.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp, error == nil else {
                NSLog("[WebRTC] Error generando SDP Offer: \(String(describing: error))")
                return
            }
            pc.setLocalDescription(sdp) { error in
                if let error = error {
                    NSLog("[WebRTC] Error seteando local description: \(error)")
                } else {
                    NSLog("[WebRTC] SDP Offer generada y enviada.")
                    self.delegate?.webRTCManager(self, didGenerateSDPOffer: sdp.sdp)
                }
            }
        }
    }

    func setRemoteAnswer(sdpString: String) {
        guard let pc = peerConnection else { return }
        let desc = RTCSessionDescription(type: .answer, sdp: sdpString)
        pc.setRemoteDescription(desc) { error in
            if let error = error {
                NSLog("[WebRTC] Error remote answer: \(error)")
            } else {
                NSLog("[WebRTC] Remote Answer OK — conexión P2P en curso.")
            }
        }
    }

    func addRemoteCandidate(sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
        guard let pc = peerConnection else { return }
        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        pc.add(candidate) { error in
            if let error = error { NSLog("[WebRTC] Error ICE candidate: \(error)") }
        }
    }

    func close() {
        peerConnection?.close()
        peerConnection = nil
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        delegate?.webRTCManager(self, didGenerateICECandidate: candidate)
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        NSLog("[WebRTC] ICE connection state: \(newState.rawValue)")
        delegate?.webRTCManager(self, didChangeIceConnectionState: newState)
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
