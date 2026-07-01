#!/usr/bin/env bash
set -euo pipefail

# Builds FocusFlow.app (via build_and_run.sh's shared bundle-assembly logic),
# ad-hoc code-signs it, and zips it into dist/ for handing to someone else's
# Mac. There is no Apple Developer certificate involved — this produces an
# unsigned-for-distribution-purposes (ad-hoc signed) build, so the recipient
# will need to bypass Gatekeeper on first launch.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="FocusFlow"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

VERSION="$(date +%Y-%m-%d)"
ZIP_NAME="FocusFlow-$VERSION.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "==> Building and assembling $APP_NAME.app"
"$ROOT_DIR/script/build_and_run.sh" --build-only >/dev/null

if [ ! -d "$APP_BUNDLE" ]; then
  echo "error: expected app bundle not found at $APP_BUNDLE" >&2
  exit 1
fi

echo "==> Ad-hoc signing $APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Zipping to $ZIP_PATH"
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo ""
echo "Done: $ZIP_PATH"
echo ""
echo "NOTE: this build is ad-hoc signed only (no Apple Developer certificate)."
echo "On first launch, the recipient must right-click (or Control-click) the"
echo "app in Finder and choose 'Open', then confirm in the dialog — otherwise"
echo "Gatekeeper will refuse to launch it."
