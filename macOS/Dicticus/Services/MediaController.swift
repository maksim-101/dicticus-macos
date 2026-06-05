import AppKit
import CoreAudio
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

    /// True when WE muted the default output this hold (pausedApp == nil tier-2
    /// fallback). Separate from `pausedApp` so resume only un-mutes output we changed.
    private var didMuteOutput = false

    /// One-shot guard so a CoreAudio mute failure logs once, not on every press.
    private var didWarnMute = false

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

    /// Resolve the system default output device, or nil if CoreAudio fails.
    private func defaultOutputDevice() -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
        return status == noErr ? dev : nil
    }

    private func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
    }

    /// Read the master mute of the default output device; nil on failure.
    ///
    /// CoreAudio first, then AppleScript fallback: built-in MacBook speakers and many
    /// external devices expose no `kAudioDevicePropertyMute` master-mute property, so
    /// the CoreAudio path silently no-ops there. `output muted of (get volume settings)`
    /// is Standard Additions (in-process, no Automation-TCC grant) and works regardless.
    private func isOutputMuted() -> Bool? {
        if let dev = defaultOutputDevice() {
            var addr = muteAddress()
            if AudioObjectHasProperty(dev, &addr) {
                var muted = UInt32(0)
                var size = UInt32(MemoryLayout<UInt32>.size)
                let status = AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &muted)
                if status == noErr { return muted != 0 }
            }
        }
        let result = runAS("output muted of (get volume settings)")
        if result.errorNumber != nil { return nil }
        switch result.value {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    /// Write the master mute of the default output device; returns success.
    ///
    /// CoreAudio first, then AppleScript fallback (`set volume output muted`,
    /// Standard Additions, in-process, no Automation-TCC grant) for devices without a
    /// CoreAudio master-mute property.
    private func setOutputMuted(_ muted: Bool) -> Bool {
        if let dev = defaultOutputDevice() {
            var addr = muteAddress()
            if AudioObjectHasProperty(dev, &addr) {
                var value = UInt32(muted ? 1 : 0)
                let size = UInt32(MemoryLayout<UInt32>.size)
                let status = AudioObjectSetPropertyData(dev, &addr, 0, nil, size, &value)
                if status == noErr { return true }
            }
        }
        let result = runAS("set volume output muted \(muted ? "true" : "false")")
        return result.errorNumber == nil
    }

    /// Degrade to a silent no-op when the CoreAudio mute API fails; log once at warn.
    private func handleMuteFailure() {
        guard !didWarnMute else { return }
        didWarnMute = true
        mediaLog.warning("MediaController: default-output mute failed — mute fallback disabled for this session")
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

        // Tier 2: only when the ScriptingBridge tier paused nothing. Mute the default
        // output to cover non-scriptable sources (browser/YouTube/podcast). We latch
        // only output WE muted — if the user already muted it, leave it untouched so
        // release never silently un-mutes a user-muted system.
        guard pausedApp == nil else { return }
        guard let muted = isOutputMuted() else { handleMuteFailure(); return }
        guard !muted else { return }
        if setOutputMuted(true) {
            didMuteOutput = true
        } else {
            handleMuteFailure()
        }
    }

    /// Resume the latched player if we paused one. Safe to call unconditionally on
    /// every release — a no-op when nothing was paused.
    func resumeMediaIfPaused() {
        if let player = pausedApp {
            pausedApp = nil
            let result = runAS("tell application \"\(player.name)\" to play")
            if let err = result.errorNumber {
                handleError(err)
            }
            return
        }
        // Mute is the else branch of the pause tier: tiers are mutually exclusive per
        // hold, so we only reach here when no scriptable player was resumed.
        guard didMuteOutput else { return }
        didMuteOutput = false
        if !setOutputMuted(false) {
            handleMuteFailure()
        }
    }
}
