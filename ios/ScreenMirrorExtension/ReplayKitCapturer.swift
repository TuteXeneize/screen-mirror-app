import Foundation
import ReplayKit
import WebRTC

/// Adaptador personalizado zero-copy entre los buffers de ReplayKit (CMSampleBuffer)
/// y el pipeline de compresión por hardware H.264 de WebRTC (RTCVideoFrame).
class ReplayKitCapturer: RTCVideoCapturer {

    func capturarFrameDeReplayKit(_ sampleBuffer: CMSampleBuffer) {
        // 1. Extraer el puntero de memoria del buffer de pixeles en bruto (Zero-Copy)
        // Esto NO duplica la memoria, protegiendo el limite de 50 MB de iOS.
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // 2. Extraer metadatos de orientación que inyecta ReplayKit al girar el iPhone
        var rtcRotation: RTCVideoRotation = ._0

        if let orientationAttachment = CMGetAttachment(
            sampleBuffer,
            key: RPVideoSampleOrientationKey as CFString,
            attachmentModeOut: nil
        ) as? NSNumber {
            let orientation = CGImagePropertyOrientation(rawValue: orientationAttachment.uint32Value)
            switch orientation {
            case .up, .upMirrored:
                rtcRotation = ._0
            case .down, .downMirrored:
                rtcRotation = ._180
            case .left, .leftMirrored:
                rtcRotation = ._90
            case .right, .rightMirrored:
                rtcRotation = ._270
            default:
                rtcRotation = ._0
            }
        }

        // 3. Extraer marca de tiempo requerida por WebRTC en nanosegundos
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timeStampNs = Int64(CMTimeGetSeconds(timestamp) * 1_000_000_000)

        // 4. Envolver en el formato nativo de WebRTC sin copiar los pixeles
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let videoFrame = RTCVideoFrame(
            buffer: rtcPixelBuffer,
            rotation: rtcRotation,
            timeStampNs: timeStampNs
        )

        // 5. Inyectar el frame directamente al codificador de video de WebRTC
        self.delegate?.capturer(self, didCapture: videoFrame)
    }
}
