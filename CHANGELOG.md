# Changelog

All notable changes to Linux Resolution Fix Reforged. Each version needs its own section,
`## <version> — <date>`, before it is released: the release workflow uses that section as the
notes on GitHub, CurseForge and Wago.

## Unreleased

- Work around fullscreen resize failures by briefly switching to a smaller window and restoring the captured target resolution.
- Prevent overlapping corrections, verify the result, and attempt to restore fullscreen and size after display errors.
- Translate the new progress and error messages into every supported language.
- Add regression tests for the correction flow, API fallbacks, error recovery, and locale coverage.

## 1.1.0 — 2026-10-01

First version of the Reforged fork of LinuxResolutionFix by maqisha.

### New

- Works on every official client: Midnight (Retail), Mists of Pandaria Classic, Burning Crusade Classic, Classic Era / Anniversary and WoW: Forever, plus their test realms. If a client lacks the needed functions, the addon says so in the chat and stays inactive.
- All 11 game languages: English, French, German, Spanish (Spain and Mexico), Italian, Brazilian Portuguese, Russian, Korean, Simplified and Traditional Chinese.
- `/lrf` checks the resolution again.
