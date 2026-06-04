<img src="docs/icon.png" width="80" align="left" hspace="14"/>

# Always With

**Default apps, sorted.**

A small macOS utility for tidying up your file-type associations. It lists every extension on your Mac, shows the app that's currently set as the default, and lets you reassign it to any other app that declared it knows how to open that kind of file.

<br clear="all"/>

![Always With main window](docs/screenshot.png)

## Install

Two ways.

### Grab the latest release

1. Download `AlwaysWith-X.Y.Z.zip` from the [Releases](https://github.com/magobaol/always-with/releases) page.
2. Unzip and drag `AlwaysWith.app` into `/Applications`.
3. First launch will be blocked by Gatekeeper because the binary is signed ad-hoc, not with an Apple Developer ID certificate. To get past it:
   - Try to open the app — macOS shows a "can't be opened" warning. Click **Done**.
   - Open **System Settings → Privacy & Security**, scroll down to the *Security* section.
   - You'll see *"AlwaysWith.app was blocked from use because it is not from an identified developer."* Click **Open Anyway** and confirm in the follow-up dialog.
   - From this point on, macOS remembers the choice and the app launches normally.

(The old "right-click → Open" trick was removed in macOS Sequoia, so Settings is now the only way.)

### Or build from source

Open `AlwaysWith.xcodeproj` in Xcode 26 or later and hit ⌘R, or from the command line:

```sh
xcodebuild -project AlwaysWith.xcodeproj -scheme AlwaysWith -configuration Debug -destination 'platform=macOS' build
```

## What it actually does

- Scans `/Applications` for installed apps and reads each `Info.plist` to find which file extensions they declare support for.
- Resolves the UTI for every extension and queries Launch Services for the current default app.
- Lets you pick any extension and reassign its default app among the ones that declared support — with the change persisted system-wide, the same way Finder's "Open With → Change All…" would do it.

## Requirements

- macOS 15.6 or later (to run)
- Xcode 26 or later (to build from source)

## Tests

```sh
xcodebuild -project AlwaysWith.xcodeproj -scheme AlwaysWith -destination 'platform=macOS' test
```

The test target uses Swift Testing.

## Notes on Launch Services APIs

`LSCopyDefaultApplicationURLForContentType` and `LSSetDefaultRoleHandlerForContentType` are deprecated since macOS 12 but they are still the only way to read and set default handlers — there is no fully modern replacement yet. The deprecation warnings on those two call sites are expected.

## License

Personal project. No license set.

---

Made with 💙 by Francesco Face
