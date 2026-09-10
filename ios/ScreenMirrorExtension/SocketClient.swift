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
            delegate?.signalingSocket(self, didFailWithError: "URL inválida: \(serverUrl)")
            return
        }

        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .reconnects(true),
            .reconnectAttempts(10),
            .reconnectWait(2)
        ])
        socket = manager?.defaultSocket
        setupHandlers()
        socket?.connect()
    }

    private func setupHandlers() {
        guard let socket = socket else { return }

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            guard let self = self else { return }
            if !self.roomCode.isEmpty {
                NSLog("[Socket] Conectado. Uniéndose a sala: \(self.roomCode)")
                socket.emit("unirse-sala", self.roomCode)
            } else {
                NSLog("[Socket] Conectado. Solicitando sala automática...")
                socket.emit("unirse-sala-automatica")
            }
        }

        socket.on("sala-unida") { [weak self] data, _ in
            guard let self = self else { return }
            if let code = data.first as? String {
                self.roomCode = code
                NSLog("[Socket] Sala confirmada: \(code)")
            }
            // Iniciar WebRTC SOLO cuando la sala está confirmada
            self.delegate?.signalingSocketDidConnect(self)
        }

        socket.on("error-sala") { [weak self] data, _ in
            guard let self = self else { return }
            let msg = data.first as? String ?? "Error de sala"
            NSLog("[Socket] Error sala: \(msg)")
            self.delegate?.signalingSocket(self, didFailWithError: msg)
        }

        socket.on("mensaje-webrtc") { [weak self] dataArray, _ in
            guard let self = self,
                  let data = dataArray.first as? [String: Any],
                  let tipo = data["tipo"] as? String else { return }

            if tipo == "answer",
               let payload = data["payload"] as? [String: Any],
               let sdp = payload["sdp"] as? String {
                self.delegate?.signalingSocket(self, didReceiveAnswer: sdp)
            } else if tipo == "ice-candidate",
                      let payload = data["payload"] as? [String: Any] {
                let candidateSdp = payload["candidate"] as? String ?? ""
                let sdpMid = payload["sdpMid"] as? String
                let sdpMLineIndex = (payload["sdpMLineIndex"] as? NSNumber)?.int32Value ?? 0
                if !candidateSdp.isEmpty {
                    self.delegate?.signalingSocket(
                        self,
                        didReceiveCandidate: candidateSdp,
                        sdpMLineIndex: sdpMLineIndex,
                        sdpMid: sdpMid
                    )
                }
            } else if tipo == "reconnect-request" {
                self.delegate?.signalingSocketDidRequestReconnect(self)
            }
        }

        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            guard let self = self else { return }
            NSLog("[Socket] Desconectado.")
            self.delegate?.signalingSocketDidDisconnect(self)
        }

        socket.on(clientEvent: .error) { [weak self] _, _ in
            guard let self = self else { return }
            NSLog("[Socket] Error de conexión.")
            self.delegate?.signalingSocket(self, didFailWithError: "Error de conexión socket")
        }
    }

    func sendSDPOffer(sdp: String) {
        let payload: [String: Any] = ["type": "offer", "sdp": sdp]
        socket?.emit("mensaje-webrtc", [
            "codigo": roomCode,
            "tipo": "offer",
            "payload": payload
        ])
        NSLog("[Socket] SDP Offer emitida.")
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
