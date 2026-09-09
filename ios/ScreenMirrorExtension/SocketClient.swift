import Foundation
import SocketIO

protocol SignalingSocketDelegate: AnyObject {
    func signalingSocketDidConnect(_ client: SignalingSocketClient)
    func signalingSocket(_ client: SignalingSocketClient, didReceiveAnswer sdp: String)
    func signalingSocket(_ client: SignalingSocketClient, didReceiveCandidate sdp: String, sdpMLineIndex: Int32, sdpMid: String?)
    func signalingSocketDidRequestReconnect(_ client: SignalingSocketClient)
    func signalingSocket(_ client: SignalingSocketClient, didFailWithError message: String)
    func signalingSocketDidDisconnect(_ client: SignalingSocketClient)
}

class SignalingSocketClient {
    weak var delegate: SignalingSocketDelegate?

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    var roomCode: String
    private let serverUrl: String

    init(serverUrl: String, roomCode: String) {
        self.serverUrl = serverUrl
        self.roomCode = roomCode
    }

    func connect() {
        guard let url = URL(string: serverUrl) else {
            delegate?.signalingSocket(self, didFailWithError: "URL de servidor inválida: \(serverUrl)")
            return
        }

        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .reconnects(true),
            .reconnectAttempts(-1),
            .reconnectWait(1)
        ])
        
        socket = manager?.defaultSocket

        setupEventHandlers()
        socket?.connect()
    }

    private func setupEventHandlers() {
        guard let socket = socket else { return }

        socket.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            if !self.roomCode.isEmpty {
                print("[Signaling] Conectado. Uniéndose a sala: \(self.roomCode)")
                socket.emit("unirse-sala", self.roomCode)
            } else {
                print("[Signaling] Conectado. Uniéndose automáticamente a la sala activa de la PC...")
                socket.emit("unirse-sala-automatica")
            }
            self.delegate?.signalingSocketDidConnect(self)
        }

        socket.on("sala-unida") { [weak self] data, ack in
            if let confirmedCode = data.first as? String {
                self?.roomCode = confirmedCode
                print("[Signaling] Sala confirmada: \(confirmedCode)")
            }
        }

        socket.on("error-sala") { [weak self] data, ack in
            guard let self = self else { return }
            let errorMsg = data.first as? String ?? "Error desconocido en sala."
            print("[Signaling] Error de sala: \(errorMsg)")
            self.delegate?.signalingSocket(self, didFailWithError: errorMsg)
        }

        // Relay WebRTC (SDP Answer, ICE Candidates, Reconnect)
        socket.on("mensaje-webrtc") { [weak self] dataArray, ack in
            guard let self = self,
                  let data = dataArray.first as? [String: Any],
                  let tipo = data["tipo"] as? String else { return }

            if tipo == "answer", let payload = data["payload"] as? [String: Any], let sdp = payload["sdp"] as? String {
                self.delegate?.signalingSocket(self, didReceiveAnswer: sdp)
            } else if tipo == "ice-candidate", let payload = data["payload"] as? [String: Any] {
                let candidateSdp = payload["candidate"] as? String ?? ""
                let sdpMid = payload["sdpMid"] as? String
                let sdpMLineIndex = (payload["sdpMLineIndex"] as? Int32) ?? 0
                self.delegate?.signalingSocket(self, didReceiveCandidate: candidateSdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
            } else if tipo == "reconnect-request" {
                print("[Signaling] El receptor solicitó reconexión.")
                self.delegate?.signalingSocketDidRequestReconnect(self)
            }
        }

        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            guard let self = self else { return }
            print("[Signaling] Desconectado del servidor.")
            self.delegate?.signalingSocketDidDisconnect(self)
        }

        socket.on(clientEvent: .error) { [weak self] data, ack in
            guard let self = self else { return }
            print("[Signaling] Error de conexión socket.")
            self.delegate?.signalingSocket(self, didFailWithError: "Error de conexión socket.")
        }
    }

    func sendSDPOffer(sdp: String) {
        let payload: [String: Any] = [
            "type": "offer",
            "sdp": sdp
        ]
        socket?.emit("mensaje-webrtc", [
            "codigo": roomCode,
            "tipo": "offer",
            "payload": payload
        ])
        print("[Signaling] SDP Offer emitida al receptor.")
    }

    func sendICECandidate(sdp: String, sdpMLineIndex: Int32, sdpMid: String?) {
        let payload: [String: Any] = [
            "candidate": sdp,
            "sdpMLineIndex": sdpMLineIndex,
            "sdpMid": sdpMid ?? ""
        ]
        socket?.emit("mensaje-webrtc", [
            "codigo": roomCode,
            "tipo": "ice-candidate",
            "payload": payload
        ])
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
    }
}
