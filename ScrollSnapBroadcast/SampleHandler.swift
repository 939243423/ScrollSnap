import ReplayKit
import CoreMedia

public final class SampleHandler: RPBroadcastSampleHandler {
    private let frameProcessor = BroadcastFrameProcessor()
    private var isRecording = false

    public override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        isRecording = true
        SharedStore.shared.resetActiveBroadcastSession()
        CrossProcessNotifier.post(name: AppGroupConstants.notificationSessionUpdated)
    }
    
    public override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard isRecording, sampleBufferType == .video else { return }
        
        // Strict autoreleasepool wrapper to destroy heap temporaries per video frame
        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            frameProcessor.process(pixelBuffer: pixelBuffer)
        }
    }
    
    public override func broadcastFinished() {
        isRecording = false
        frameProcessor.finalizeSession()
        CrossProcessNotifier.post(name: AppGroupConstants.notificationSessionCompleted)
    }
}
