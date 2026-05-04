#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/DisplayFill.xcodeproj}"
SCHEME="${SCHEME:-DisplayFill}"
CONFIGURATION="${CONFIGURATION:-AppStore}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/appstore}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_DIR/$SCHEME-AppStore.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-$DIST_DIR/export}"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/AppStoreExportOptions.plist"
UPLOAD="${UPLOAD:-0}"

fail() {
	echo "error: $*" >&2
	exit 1
}

read_build_setting() {
	local key="$1"
	xcodebuild \
		-project "$PROJECT_PATH" \
		-scheme "$SCHEME" \
		-configuration "$CONFIGURATION" \
		-showBuildSettings \
		2>/dev/null \
	| awk -F ' = ' -v key="$key" '$1 ~ ("^[[:space:]]*" key "$") { print $2; exit }'
}

xcode_auth_args=()
if [[ -n "${ASC_KEY_PATH:-}" || -n "${ASC_KEY_ID:-}" || -n "${ASC_ISSUER_ID:-}" ]]; then
	[[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]] \
		|| fail "ASC_KEY_PATH, ASC_KEY_ID, and ASC_ISSUER_ID must be set together."
	xcode_auth_args=(
		-authenticationKeyPath "$ASC_KEY_PATH"
		-authenticationKeyID "$ASC_KEY_ID"
		-authenticationKeyIssuerID "$ASC_ISSUER_ID"
	)
fi

TEAM_ID="${TEAM_ID:-$(read_build_setting DEVELOPMENT_TEAM)}"
[[ -n "$TEAM_ID" ]] || fail "TEAM_ID is required. Export TEAM_ID or set DEVELOPMENT_TEAM in Xcode."

DESTINATION="export"
if [[ "$UPLOAD" == "1" ]]; then
	DESTINATION="upload"
fi

mkdir -p "$BUILD_DIR" "$DIST_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>$DESTINATION</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
EOF

echo "Archiving $SCHEME ($CONFIGURATION) for Mac App Store..."
xcodebuild archive \
	-project "$PROJECT_PATH" \
	-scheme "$SCHEME" \
	-configuration "$CONFIGURATION" \
	-destination "generic/platform=macOS" \
	-archivePath "$ARCHIVE_PATH" \
	DEVELOPMENT_TEAM="$TEAM_ID" \
	CODE_SIGN_STYLE=Automatic \
	-allowProvisioningUpdates \
	"${xcode_auth_args[@]}"

echo "Exporting App Store Connect archive (destination: $DESTINATION)..."
xcodebuild -exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_DIR" \
	-exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
	-allowProvisioningUpdates \
	"${xcode_auth_args[@]}"

if [[ "$UPLOAD" == "1" ]]; then
	echo "Uploaded build to App Store Connect. It may take several minutes to finish processing."
else
	PACKAGE_PATH="$(find "$EXPORT_DIR" -maxdepth 1 \( -name '*.pkg' -o -name '*.ipa' \) -print -quit)"
	[[ -n "$PACKAGE_PATH" ]] || fail "Export finished but no upload package was found in $EXPORT_DIR."
	echo "App Store export artifact: $PACKAGE_PATH"
fi
