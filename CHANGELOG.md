# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.8] - 2026-07-01

### Added
- Manually add a file extension that no installed app declares (for example `.env`, which macOS only maps to a dynamic type). Use the new **+** button in the toolbar, or the inline **Add** action shown when a filtered search returns no matches. Manually-added extensions are remembered across launches.
- For an extension no app declares, the **Change to** list now suggests every app that can open plain text, so you can still pick a sensible default.
- New **Choose other app…** action in the detail pane opens a file panel to assign any app on your Mac, mirroring Finder's "Other…".

## [1.0.7] - 2026-06-05

A complete visual identity refresh and a redesign of the main window.

### Added
- New app icon (a fan of colored cards on a blue gradient) and an "Always With" wordmark with the tagline "Default apps, sorted.", set in Nunito.
- Branded full-width toolbar with the app icon, wordmark, native search field (with the standard ⌘F shortcut and a clear button), and a refresh button.
- Three-column sidebar with user-resizable columns, alternating row backgrounds, real macOS app icons next to each default app, and an accent-blue selection highlight.
- Redesigned detail pane: extension badge, file-type description, a "Currently opens with" card (app icon + name + install path), a "Change to" picker list, and a single right-aligned "Set as default" button with a green success flash on apply.
- New empty state shown when no extension is selected (app icon, "Pick an extension" heading, helpful subtitle).
- Full keyboard navigation: arrow / page / home / end keys move the selection within the focused list; Tab cycles through search → refresh → main list → "Change to" → "Set as default" and back; focus indicators only appear during keyboard navigation and disappear on the next mouse click.
- Search field clears with its native X button and the list snaps back to keep the previously-selected extension visible.

### Changed
- The menu bar and Dock now show "Always With" with a space (was "AlwaysWith").
- The heart in the status bar is now tinted with the brand accent blue.

### Removed
- The "Always With Help" menu item, which previously only opened an empty placeholder modal.
