# Blink

<img src="Blink/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="Blink app icon: a pixel-art bird">

A tiny macOS menu bar app that reminds you to **blink and look away** from the screen, to reduce eye strain.

Every few minutes (you choose how often), a small card pops up in the corner with a soft chirp and a pixel-art view into the distance. Look at something far away until the countdown ends, then carry on.

## Features

- Lives in the menu bar: no Dock icon, no windows.
- **Remind every** 5 to 60 minutes, with a **break length** from 20 seconds to 10 minutes.
- Live countdown next to the icon and in the menu, while a little hand writes on a scroll (and a bird runs by now and then).
- When the break is over, the card waits for you, counting the extra time, until you click **Continue**.
- Doesn't count while your screen is locked, while your Mac sleeps, or when you've been away from the keyboard for 5 minutes.
- Pause anytime: the bird naps in the menu bar until you resume.
- English and Brazilian Portuguese (follows your macOS language).

Requires macOS 14 (Sonoma) or later. Runs on Apple silicon and Intel Macs.

## Install

### Option 1: one line in Terminal (recommended)

Open **Terminal** and paste:

```sh
curl -fsSL https://raw.githubusercontent.com/pizzani/blink/main/install.sh | bash
```

This downloads the latest release, puts Blink in your Applications folder and starts it. Run it again anytime to update. ([See what the script does.](install.sh))

### Option 2: download

1. Download **Blink.zip** from the [latest release](https://github.com/pizzani/blink/releases/latest) and open it.
2. Drag **Blink** to your **Applications** folder and open it.
3. macOS will say it can't verify the developer. Click **Done**, then go to **System Settings › Privacy & Security**, scroll down and click **Open Anyway** next to the message about Blink. You only need to do this once.

> **Why the warning?** Blink isn't signed with a paid Apple Developer ID, so macOS can't verify who made it. The Terminal option skips the prompt because files downloaded with `curl` aren't flagged the way browser downloads are. The code is all here if you'd like to check it.

To start Blink when you log in, add it in **System Settings › General › Login Items**.

## Build from source

You need Xcode 16 or later.

```sh
git clone https://github.com/pizzani/blink.git
cd blink
open Blink.xcodeproj
```

Then press **⌘R**. Debug builds also offer a 30-second interval for testing.

## Making a release

```sh
Tools/release.sh
```

This builds a universal Release version, zips it and publishes a GitHub Release tagged with the app version (`MARKETING_VERSION` in the project). It needs the [GitHub CLI](https://cli.github.com) (`brew install gh && gh auth login`); without it, the script builds the zip and tells you how to upload it by hand. Bump the version before each new release.

The app icon is generated from the pixel bird with `swift Tools/make-app-icon.swift Blink/Assets.xcassets/AppIcon.appiconset`.

## License

[MIT](LICENSE)
