import Foundation
import ReplayKit
import WebRTC

/// Adaptador zero-copy entre los CMSampleBuffer de ReplayKit
/// y el pipeline de compresión H.264 por hardware de WebRTC.
class ReplayKitCapturer: RTCVideoCapturer {

    func capturarFrameDeReplayKit(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Orientación del frame
        var rotation: RTCVideoRotation = ._0
        if let orientationRaw = CMGetAttachment(
            sampleBuffer,
            key: RPVideoSampleOrientationKey as CFString,
            attachmentModeOut: nil
        ) as? NSNumber,
           let orientation = CGImagePropertyOrientation(rawValue: orientationRaw.uint32Value) {
            switch orientation {
            case .up, .upMirrored:    rotation = ._0
            case .down, .downMirrored: rotation = ._180
            case .left, .leftMirrored: rotation = ._90
            case .right, .rightMirrored: rotation = ._270
            default: rotation = ._0
            }
        }

        // Timestamp en nanosegundos
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timeNs = Int64(CMTimeGetSeconds(pts) * 1_000_000_000)

        // Envolver sin copiar los píxeles
        let rtcBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let frame = RTCVideoFrame(buffer: rtcBuffer, rotation: rotation, timeStampNs: timeNs)

        delegate?.capturer(self, didCapture: frame)
    }
}
