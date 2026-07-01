# Backlog

Use this file to track improvement ideas, suspected bugs and "maybe" experiments. New items go on top of the relevant section. When an item ships, move it under **Done** with the version that shipped it.

## Improvements

- [ ] Let the user manually add an extension that no installed app declares, so files like `.env` become manageable. The list is currently built purely from apps' `Info.plist` (`AppScanner` → `declaredExtensions` → `AssociationsModel.buildAssociations`), so an extension that no app declares never appears — and extensions like `env` resolve only to a *dynamic* UTI (`UTType(filenameExtension: "env")` → `dyn.…`, `isDeclared == false`), so nothing brings them into the scan. Two entry points, both opening the same sheet: a `+` button in the toolbar (always visible) and an inline "Add \".env\" manually" action shown in the sidebar's "No matches" empty state (reuses the text already typed in the filter). Persistence: manually-added extensions are remembered (e.g. `UserDefaults`) and merged back into the scanned list on every launch — the system-wide association written by `LSSetDefaultRoleHandlerForContentType` already survives on its own, but the *row* in the list does not, since the scan can't reconstruct it. Two technical nodes to resolve while building: (a) candidate apps to offer — a dynamic-UTI extension has no declaring apps, so the sheet suggests apps that declare `public.plain-text` / `public.text` plus a "Choose other app…" panel for anything else; (b) verify that `LSSetDefaultRoleHandlerForContentType` on a dynamic (`dyn.…`) UTI actually persists and doesn't fail silently — if it doesn't hold, the whole approach needs rethinking, so test this first.
- [ ] Add a category filter that groups extensions by their general kind — video, images, audio, text, code, archives, binaries, etc. — so the user can quickly browse "all video extensions" without typing. The natural data source is `UTType` conformance: walking the parent chain of each extension's UTI against `.image`, `.movie`, `.audio`, `.text`, `.sourceCode`, `.archive`, etc. UI is the open question: segmented picker / pill bar above the list, popover from a button in the toolbar, or a dropdown next to the filter field. Also: does the category combine with the text filter (AND) or replace it?
- [ ] Align the entire auto-update UI with standard macOS patterns. This is not only about adding an explicit "Install and Relaunch" confirmation step after the download completes, but also about reworking the release notes sheet itself (typography hierarchy, header, button placement) to match what native Mac apps do at this stage. See screenshots in `references/` (added by the user) for the target pattern.
- [ ] Sign the app with a real Developer ID certificate and notarize the release zip. Would eliminate the "unidentified developer" warning on first launch, remove the need to manually strip quarantine, and stop App Translocation from kicking in for new installs. Requires an Apple Developer account.
- [ ] Add a "Check for updates now" menu item (e.g. under the app menu) so the user can re-trigger `UpdateChecker.check()` without restarting the app.

## Bug ideas / suspected issues

- [ ] Status bar at very narrow window widths: the `count · update badge · credit` HStack has no `lineLimit` or `Spacer(minLength:)`. Should verify behaviour around 600pt width and tighten if it overflows.

## Maybe / nice to have

- [ ] Add a small "search this extension on the web" affordance next to the extension in the detail header (e.g. a magnifying-glass icon). Useful especially for obscure extensions where `UTType.localizedDescription` returns nothing. Always present (not just when Kind is missing), so the position is predictable. Candidate destinations: `https://file.org/extension/<ext>` (preferred) or `https://fileinfo.com/extension/<ext>`.
- [ ] Migrate the homebrew auto-updater to Sparkle. Sparkle gives EdDSA-signed update verification, a richer progress UI, and "skip this version" / snooze features out of the box. Only worth the refactor if the app starts being shipped to non-developer users.

## Done

### 1.0.7 — visual identity & UI redesign

- New app icon (fan-of-cards on blue gradient, `.aw` chip).
- Wordmark "Always With" + tagline "Default apps, sorted." in Nunito (variable font bundled), blue accent `#2F6FE0` adopted across selection, badges, success-flash green, primary button.
- Full-width branded toolbar with icon + wordmark, native search field, refresh button. Display name and menu-bar name unified to "Always With".
- Sidebar rebuilt as a custom three-column list with resizable header separators (drag handle with col-resize cursor, accent-blue while dragging), alternating row backgrounds, accent-tint selection highlight, and real `NSWorkspace` app icons in the "Default app" column. App icons are cached by URL for filtering responsiveness.
- Detail pane redesigned: extension badge + UTI description + supporting-app count copy ("1 app can open it" handles the singular); "Currently opens with" card with green-flash + "✓ Updated" tag on apply; "Change to" picker list with no radios / no current-marker; single right-aligned "Set as default" button. Replaces the old `NavigationSplitView`.
- New empty-state screen (app icon + "Pick an extension" + subtitle) shown when no extension is selected.
- Keyboard support: ⌘F focuses the search field, arrow / page / home / end navigate the focused list (with key-repeat) without dragging the selection out of view, Tab cycles through search → refresh → main list → "Change to" → "Set as default" and back. Focus indicators (custom accent border on lists, system ring on the button) are gated on a `:focus-visible`-style InteractionMode that only flips on after a keyboard event and back off on the next mouse click.
- Status bar updated with the heart in accent blue. Window tabbing disabled at app launch.
