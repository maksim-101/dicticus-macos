---
status: partial
phase: 01-foundation-app-shell
source: [01-VERIFICATION.md]
started: 2026-04-15
updated: 2026-04-15
---

## Current Test

[awaiting human testing]

## Tests

### 1. App launches as menu bar agent
expected: No Dock icon appears, no main window — only menu bar icon visible
result: [pending]

### 2. Light/dark mode icon rendering
expected: SF Symbol "mic" adapts to macOS light/dark appearance automatically
result: [pending]

### 3. Sequential onboarding on first launch
expected: Three-step flow (Microphone -> Accessibility -> Input Monitoring) with skip links
result: [pending]

### 4. Permission polling
expected: Grant in System Settings reflects in dropdown within ~2 seconds
result: [pending]

### 5. Grant Access / Open Settings buttons
expected: OS prompts appear and correct System Settings panes open
result: [pending]

### 6. Warm-up progress and icon pulse
expected: Menu bar icon pulses during CoreML compilation, stops when ready
result: [pending]

### 7. mic vs mic.slash icon state
expected: Icon switches based on permission state (mic when all granted, mic.slash when any missing)
result: [pending]

### 8. Error state on model load failure
expected: Red error text in dropdown, app remains functional
result: [pending]

## Summary

total: 8
passed: 0
issues: 0
pending: 8
skipped: 0
blocked: 0

## Gaps
