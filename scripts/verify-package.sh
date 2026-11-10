#!/bin/bash
# Check the packaged app after scripts/build-app.sh. Runs on the macOS runner.
# A Gatekeeper rejection is expected and is recorded. It does not fail the build.
set -euo pipefail

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
REPORT="$DIST/package-report.txt"
: > "$REPORT"

fail() {
  echo "PACKAGE CHECK FAILED: $*" | tee -a "$REPORT" >&2
  exit 1
}

note() {
  echo "$*" | tee -a "$REPORT"
}

shopt -s nullglob
APPS=( "$DIST"/*.app )
if [[ ${#APPS[@]} -ne 1 ]]; then
  fail "expected one .app in dist, found ${#APPS[@]}"
fi
APP="${APPS[0]}"
ZIP=( "$DIST"/PersonalTools-*-macOS.zip )
DMG=( "$DIST"/PersonalTools-*-macOS.dmg )
if [[ ${#ZIP[@]} -ne 1 || ${#DMG[@]} -ne 1 ]]; then
  fail "expected one zip and one dmg"
fi

note "App: $APP"
note "Zip: ${ZIP[0]}"
note "Dmg: ${DMG[0]}"

EXE="$APP/Contents/MacOS/PersonalTools"
[[ -x "$EXE" ]] || fail "missing executable"

IDENT="$(plutil -extract CFBundleIdentifier raw -o - "$APP/Contents/Info.plist")"
MINOS="$(plutil -extract LSMinimumSystemVersion raw -o - "$APP/Contents/Info.plist")"
BUNDLE_EXE="$(plutil -extract CFBundleExecutable raw -o - "$APP/Contents/Info.plist")"
UI_ELEMENT="$(plutil -extract LSUIElement raw -o - "$APP/Contents/Info.plist")"
MARKETING="$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist")"
note "CFBundleIdentifier: $IDENT"
note "CFBundleShortVersionString: $MARKETING"
note "LSMinimumSystemVersion: $MINOS"
note "LSUIElement: $UI_ELEMENT"
[[ "$IDENT" == "com.yerled.personaltools" ]] || fail "unexpected bundle id $IDENT"
[[ "$MINOS" == "13.0" ]] || fail "unexpected minimum system $MINOS"
[[ "$BUNDLE_EXE" == "PersonalTools" ]] || fail "unexpected executable name $BUNDLE_EXE"
[[ "$UI_ELEMENT" == "true" ]] || fail "app should be an agent (LSUIElement)"

LIPO_INFO="$(lipo -info "$EXE")"
note "lipo: $LIPO_INFO"
[[ "$LIPO_INFO" == *"arm64"* && "$LIPO_INFO" == *"x86_64"* ]] || fail "not a universal binary: $LIPO_INFO"

FILE_INFO="$(file "$EXE")"
note "file: $FILE_INFO"

VTOOL="$(vtool -show-build "$EXE")"
note "vtool:"
note "$VTOOL"
MINOS_LINES="$(printf '%s\n' "$VTOOL" | awk '/minos/ { print $2 }')"
[[ -n "$MINOS_LINES" ]] || fail "no minos"
while IFS= read -r line; do
  major="${line%%.*}"
  [[ "$major" == "13" ]] || fail "minos is $line, expected 13.x"
done <<< "$MINOS_LINES"

note "codesign:"
CODESIGN="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
note "$CODESIGN"
printf '%s\n' "$CODESIGN" | grep -E -q 'Signature=adhoc|flags=0x2\(adhoc\)' || fail "signature is not ad-hoc"
if printf '%s\n' "$CODESIGN" | grep -E -q 'Authority=Developer ID|Notarization Ticket'; then
  fail "package unexpectedly looks Developer ID signed or notarized"
fi
note "Notarization: none. Signature is ad-hoc only."

note "spctl (expected to reject an unnotarized download):"
set +e
SPCTL="$(spctl --assess --verbose=4 --type execute "$APP" 2>&1)"
SPCTL_STATUS=$?
set -e
note "$SPCTL"
note "spctl exit: $SPCTL_STATUS"

note "zip entries:"
# Capture the listing first. `grep -q` exits early and SIGPIPE makes unzip
# return non-zero, which `pipefail` would treat as a missing executable.
ZIP_LISTING="$(unzip -l "${ZIP[0]}")"
printf '%s\n' "$ZIP_LISTING" | tee -a "$REPORT"
printf '%s\n' "$ZIP_LISTING" | grep -q "Contents/MacOS/PersonalTools" || fail "zip is missing the executable"

note "sha256:"
shasum -a 256 "${ZIP[0]}" "${DMG[0]}" | tee -a "$REPORT"
note "Architectures: arm64 x86_64"
note "Minimum macOS: 13.0"
note "Signing: ad-hoc (--sign -). Not notarized."
note "PACKAGE CHECK PASSED"
