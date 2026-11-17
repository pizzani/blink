#!/bin/bash
# Builds a universal (Apple silicon + Intel) Release of Blink, zips it, and publishes it
# as a GitHub Release tagged with the app's version (MARKETING_VERSION).
#
#   Tools/release.sh            build, zip and publish
#   Tools/release.sh --no-publish   only build and zip
#
# Publishing needs the GitHub CLI, signed in: brew install gh && gh auth login
#
# The app is ad-hoc signed (no paid Apple Developer ID), so downloads from a browser show
# Gatekeeper's "Open Anyway" prompt once; install.sh avoids it. See the README.

set -euo pipefail

cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT=build/release
VERSION=$(grep -m1 "MARKETING_VERSION" Blink.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);/\1/')
TAG="v$VERSION"
ZIP="$OUT/Blink.zip"

echo "==> Building Blink $VERSION (Release, universal)"
rm -rf "$OUT"
xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Release -destination "generic/platform=macOS" \
    -derivedDataPath "$OUT/DerivedData" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    build -quiet

APP="$OUT/DerivedData/Build/Products/Release/Blink.app"
lipo -archs "$APP/Contents/MacOS/Blink"

echo "==> Zipping"
# ditto keeps the bundle's symlinks, permissions and signature intact.
ditto -c -k --keepParent "$APP" "$ZIP"
echo "$ZIP ($(du -h "$ZIP" | cut -f1))"

if [[ "${1:-}" == "--no-publish" ]]; then
    exit 0
fi

if ! command -v gh >/dev/null; then
    cat <<EOF

GitHub CLI not found, so the release wasn't published. Either install it
(brew install gh && gh auth login) and rerun, or publish by hand:
  1. https://github.com/pizzani/blink/releases/new
  2. Tag: $TAG   Title: Blink $VERSION
  3. Attach $ZIP (keep the name Blink.zip; install.sh downloads it by that name)
EOF
    exit 0
fi

if gh release view "$TAG" >/dev/null 2>&1; then
    echo "Release $TAG already exists. Bump MARKETING_VERSION in the project for a new release." >&2
    exit 1
fi

echo "==> Publishing $TAG"
git push origin HEAD
gh release create "$TAG" "$ZIP" --title "Blink $VERSION" --generate-notes
