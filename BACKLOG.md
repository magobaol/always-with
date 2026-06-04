# Backlog

Use this file to track improvement ideas, suspected bugs and "maybe" experiments. New items go on top of the relevant section. When an item ships, move it under **Done** with the version that shipped it.

## Improvements

- [ ] Align the entire auto-update UI with standard macOS patterns. This is not only about adding an explicit "Install and Relaunch" confirmation step after the download completes, but also about reworking the release notes sheet itself (typography hierarchy, header, button placement) to match what native Mac apps do at this stage. See screenshots in `references/` (added by the user) for the target pattern.
- [ ] Revisit using `Table` for the extensions list. The previous attempt was reverted because column resize did not work inside the `NavigationSplitView` sidebar on macOS 26. Possible directions: move the `Table` to the detail area instead of the sidebar; switch to `HSplitView` for a native drag-handle; find a working `Table` configuration under `NavigationSplitView`.
- [ ] Sign the app with a real Developer ID certificate and notarize the release zip. Would eliminate the "unidentified developer" warning on first launch, remove the need to manually strip quarantine, and stop App Translocation from kicking in for new installs. Requires an Apple Developer account.
- [ ] Add a "Check for updates now" menu item (e.g. under the app menu) so the user can re-trigger `UpdateChecker.check()` without restarting the app.
- [ ] Show each app's icon (loaded via `NSWorkspace.shared.icon(forFile:)`) next to its name in the supporting apps list, so rows are visually scannable.

## Bug ideas / suspected issues

- [ ] Status bar at very narrow window widths: the `count · update badge · credit` HStack has no `lineLimit` or `Spacer(minLength:)`. Should verify behaviour around 600pt width and tighten if it overflows.

## Maybe / nice to have

- [ ] Add a small "search this extension on the web" affordance next to the extension in the detail header (e.g. a magnifying-glass icon). Useful especially for obscure extensions where `UTType.localizedDescription` returns nothing. Always present (not just when Kind is missing), so the position is predictable. Candidate destinations: `https://file.org/extension/<ext>` (preferred) or `https://fileinfo.com/extension/<ext>`.
- [ ] The main app window feels somewhat anonymous: the toolbar has no identity markers. Evaluate ways to make the window read more clearly as Always with — an app icon or wordmark in the toolbar, or other identity elements.
- [ ] Migrate the homebrew auto-updater to Sparkle. Sparkle gives EdDSA-signed update verification, a richer progress UI, and "skip this version" / snooze features out of the box. Only worth the refactor if the app starts being shipped to non-developer users.

## Done
