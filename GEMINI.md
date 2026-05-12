# Dicticus Development Guidelines

## Project-Specific Mandates

### Code Signing & Permission Persistence
- ** stable Identity is Critical**: macOS TCC (Transparency, Consent, and Control) permissions (Microphone, Accessibility, Input Monitoring) are tied to the application's code signature.
- **NEVER use ad-hoc signing** for the final installed app in `/Applications`. Ad-hoc signatures change with every build, forcing the user to re-grant permissions on every relaunch.
- **ALWAYS re-sign with Developer ID**: After building locally (e.g., via `xcodebuild`), the app must be re-signed using a valid Developer ID Application identity (e.g., `Developer ID Application: Moritz Wehrli (VTWHBCCP36)`).
- **Cleanup build pollution**: Before re-signing the canonical `/Applications/Dicticus.app`, ensure all other copies of the app (e.g., in `DerivedData` or local `build/` folders) are removed to prevent macOS from confusing the active identity.

### Build & Install Workflow
1. Build the target (Release or Debug-Recorder).
2. Stop any running instances of Dicticus.
3. Trash non-canonical copies (DerivedData, local build dirs).
4. Copy the new build to `/Applications/Dicticus.app`.
5. Re-sign `/Applications/Dicticus.app` deeply with the Developer ID.
6. Open the app.

## Development lifecycle
- See `ROADMAP.md` for phase history and `STATE.md` for current position.
- JSONL Debug Recording is gated by the `DEBUG_RECORDER` flag. Use the `Dicticus-Debug-Recorder` scheme to enable local pattern analysis.
