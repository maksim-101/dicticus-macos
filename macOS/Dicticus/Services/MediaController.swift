import Foundation
import os

private let mediaLog = Logger(subsystem: "com.dicticus", category: "media-control")

// MRCommand constants validated in Spike 002a.
private let kMRPlay  = 0
private let kMRPause = 1

// dlsym typealiases (proven signatures from Spike 002a-mediaremote.swift).
private typealias IsPlayingFn   = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
private typealias SendCommandFn = @convention(c) (Int, [AnyHashable: Any]?) -> Bool

/// Guarded MediaRemote play-state reader and command sender.
///
/// Resolves `MRMediaRemoteGetNowPlayingApplicationIsPlaying` and
/// `MRMediaRemoteSendCommand` via dlopen/dlsym at construction time.
/// If the framework or either symbol is unavailable (future macOS breakage),
/// `available` is set to false, one warn-level log is emitted, and every
/// public method becomes a no-op — the feature degrades silently, never crashes.
///
/// Algorithm (from CONTEXT.md):
///   pauseMediaIfPlaying()  — fire on PTT press, AFTER startRecording() succeeds.
///   resumeMediaIfPaused()  — fire on PTT release.
/// The `didPauseMedia` latch ensures we only resume media that *we* paused.
@MainActor
final class MediaController {

    /// True when both MediaRemote symbols resolved successfully.
    private let available: Bool

    private let isPlayingFn: IsPlayingFn?
    private let sendCommandFn: SendCommandFn?

    /// Latch: true when we sent the pause command. Resume is a no-op unless this is set.
    private var didPauseMedia = false

    init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let handle = dlopen(path, RTLD_NOW) else {
            mediaLog.warning("MediaController: dlopen failed for MediaRemote — media pause disabled")
            available = false
            isPlayingFn = nil
            sendCommandFn = nil
            return
        }

        guard let isPlayingPtr = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") else {
            mediaLog.warning("MediaController: MRMediaRemoteGetNowPlayingApplicationIsPlaying not found — media pause disabled")
            available = false
            isPlayingFn = nil
            sendCommandFn = nil
            return
        }

        guard let sendPtr = dlsym(handle, "MRMediaRemoteSendCommand") else {
            mediaLog.warning("MediaController: MRMediaRemoteSendCommand not found — media pause disabled")
            available = false
            isPlayingFn = nil
            sendCommandFn = nil
            return
        }

        isPlayingFn   = unsafeBitCast(isPlayingPtr, to: IsPlayingFn.self)
        sendCommandFn = unsafeBitCast(sendPtr, to: SendCommandFn.self)
        available = true
    }

    /// Read play-state asynchronously; if playing, send pause and set the latch.
    ///
    /// Must be called AFTER `startRecording()` succeeds so that early-exit paths
    /// (model not ready, busy, mode mismatch) never reach this call.
    /// The read is async — recording begins immediately without waiting for the callback.
    func pauseMediaIfPlaying() {
        didPauseMedia = false
        guard available, let isPlaying = isPlayingFn, let send = sendCommandFn else { return }

        isPlaying(DispatchQueue.main) { [weak self] playing in
            guard let self else { return }
            if playing {
                _ = send(kMRPause, nil)
                self.didPauseMedia = true
            }
        }
    }

    /// Resume media if we were the one who paused it.
    ///
    /// Safe to call unconditionally on every PTT release — is a no-op when
    /// `didPauseMedia` is false (nothing was paused by us) or when unavailable.
    /// The toggle does not need re-checking here: if the toggle was off at
    /// press time, `didPauseMedia` is false and this is already a no-op.
    func resumeMediaIfPaused() {
        guard available, let send = sendCommandFn else { return }
        guard didPauseMedia else { return }
        _ = send(kMRPlay, nil)
        didPauseMedia = false
    }
}
