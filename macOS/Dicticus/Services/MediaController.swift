import AppKit
import Foundation
import os

private let mediaLog = Logger(subsystem: "com.dicticus", category: "media-control")

/// Pauses/resumes the currently-audible desktop media player while PTT is held.
///
/// Uses ScriptingBridge / Apple events (validated signed in Spike 003d) to control
/// Apple Music and Spotify — MediaRemote's now-playing read is entitlement-gated in
/// the signed/hardened-runtime app and was dropped. Requires the
/// `com.apple.security.automation.apple-events` entitlement plus a one-time
/// Automation TCC grant; if automation is denied, every method degrades to a silent
/// no-op (one warn log).
///
/// Algorithm (from 30-CONTEXT):
///   pauseMediaIfPlaying()  — fire on PTT press, AFTER startRecording() succeeds.
///   resumeMediaIfPaused()  — fire on PTT release.
/// The `pausedApp` latch holds the SPECIFIC player we paused so resume targets only
/// that app — we never start media that wasn't already playing.
@MainActor
final class MediaController {

    private struct Player {
        let name: String
        let bundleID: String
    }

    private let players = [
        Player(name: "Music", bundleID: "com.apple.Music"),
        Player(name: "Spotify", bundleID: "com.spotify.client"),
    ]

    /// The specific player we paused this hold; nil when nothing was paused.
    private var pausedApp: Player?

    /// One-shot guard so a denied Automation grant logs once, not on every press.
    private var didWarnPermission = false

    /// Running-check via NSWorkspace (no Apple event) so we never LAUNCH a stopped
    /// player just to query it — `tell application "X"` blind would start it.
    private func isRunning(_ bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    /// Runs an AppleScript source, returning its string value or an error number.
    private func runAS(_ src: String) -> (value: String?, errorNumber: Int?) {
        var err: NSDictionary?
        guard let script = NSAppleScript(source: src) else { return (nil, nil) }
        let out = script.executeAndReturnError(&err)
        if let err {
            let num = (err[NSAppleScript.errorNumber] as? Int)
            return (nil, num)
        }
        return (out.stringValue, nil)
    }

    /// Degrade to a silent no-op when Automation TCC is denied (errAEEventNotPermitted
    /// / -1743) or any AppleScript error occurs; log once at warn, never crash or retry.
    private func handleError(_ errorNumber: Int) {
        guard !didWarnPermission else { return }
        didWarnPermission = true
        mediaLog.warning("MediaController: Apple event failed (\(errorNumber)) — media pause disabled for this session")
    }

    /// Pause the one running player that is audibly playing; latch it for resume.
    ///
    /// Must be called AFTER `startRecording()` succeeds so rejected presses (model not
    /// ready, busy, mode mismatch, sub-threshold) never reach this call.
    func pauseMediaIfPlaying() {
        pausedApp = nil
        for player in players where isRunning(player.bundleID) {
            let state = runAS("tell application \"\(player.name)\" to return (player state as text)")
            if let err = state.errorNumber {
                handleError(err)
                continue
            }
            if state.value == "playing" {
                let result = runAS("tell application \"\(player.name)\" to pause")
                if let err = result.errorNumber {
                    handleError(err)
                    continue
                }
                pausedApp = player
                break
            }
        }
    }

    /// Resume the latched player if we paused one. Safe to call unconditionally on
    /// every release — a no-op when nothing was paused.
    func resumeMediaIfPaused() {
        guard let player = pausedApp else { return }
        pausedApp = nil
        let result = runAS("tell application \"\(player.name)\" to play")
        if let err = result.errorNumber {
            handleError(err)
        }
    }
}
