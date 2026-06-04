# Backlog

Use this file to track improvement ideas, suspected bugs and "maybe" experiments. New items go on top of the relevant section. When an item ships, move it under **Done** with the version that shipped it.

## In progress

- **Visual identity & UI redesign** (per `references/design-handoff/`). New app icon (fan-of-cards, `.aw` chip, blue gradient), wordmark + tagline "Default apps, sorted.", blue accent `#2F6FE0`, full-width branded toolbar, resizable-column `Table` for the sidebar with real app icons, redesigned detail pane ("Currently opens with" card + "Change to" picker + single "Set as default" button with success flash), new empty state. Subsumes Improvements items 2 and 5 and Maybe item "anonymous main window".

## Improvements

- [ ] Align the entire auto-update UI with standard macOS patterns. This is not only about adding an explicit "Install and Relaunch" confirmation step after the download completes, but also about reworking the release notes sheet itself (typography hierarchy, header, button placement) to match what native Mac apps do at this stage. See screenshots in `references/` (added by the user) for the target pattern.
- [ ] Sign the app with a real Developer ID certificate and notarize the release zip. Would eliminate the "unidentified developer" warning on first launch, remove the need to manually strip quarantine, and stop App Translocation from kicking in for new installs. Requires an Apple Developer account.
- [ ] Add a "Check for updates now" menu item (e.g. under the app menu) so the user can re-trigger `UpdateChecker.check()` without restarting the app.

## Bug ideas / suspected issues

- [ ] Status bar at very narrow window widths: the `count · update badge · credit` HStack has no `lineLimit` or `Spacer(minLength:)`. Should verify behaviour around 600pt width and tighten if it overflows.

## Maybe / nice to have

- [ ] Add a small "search this extension on the web" affordance next to the extension in the detail header (e.g. a magnifying-glass icon). Useful especially for obscure extensions where `UTType.localizedDescription` returns nothing. Always present (not just when Kind is missing), so the position is predictable. Candidate destinations: `https://file.org/extension/<ext>` (preferred) or `https://fileinfo.com/extension/<ext>`.
- [ ] Migrate the homebrew auto-updater to Sparkle. Sparkle gives EdDSA-signed update verification, a richer progress UI, and "skip this version" / snooze features out of the box. Only worth the refactor if the app starts being shipped to non-developer users.

## Done
