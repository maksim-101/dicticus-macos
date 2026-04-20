# Phase 11: Transcription History - Discussion Log

**Date:** 2026-04-19
**Phase:** 11-transcription-history
**Areas discussed:** Storage (GRDB vs SwiftData), UI Design (Window vs Popover), FTS5 Integration.

---

## Storage Engine

| Option | Description | Rationale |
|--------|-------------|-----------|
| GRDB | Mature, high-performance SQLite wrapper with excellent FTS5 support. | Highly recommended for "Pro" apps needing reliable local storage and advanced search. |
| SwiftData | Apple's modern persistence framework. | Easier to set up, but FTS5 support is not as robust or explicit as GRDB. |

**Decision Candidate:** GRDB (as specified in roadmap).

---

## UI Design

| Option | Description | Rationale |
|--------|-------------|-----------|
| Separate Window | Button in menu bar opens a standard macOS window. | Best for "reviewing" long lists and searching. |
| Popover | History list appears inside the menu bar dropdown. | Quick access, but can become cramped. |

**Decision Candidate:** Separate Window.
