#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: package_unsigned_ipa.sh /path/to/App.app [output.ipa]}"
OUTPUT_PATH="${2:-unsigned-build.ipa}"

if [[ ! -d "$APP_PATH" || "${APP_PATH##*.}" != "app" ]]; then
  echo "Expected a built .app directory: $APP_PATH" >&2
  exit 2
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/Payload" "$(dirname "$OUTPUT_PATH")"
cp -R "$APP_PATH" "$WORK_DIR/Payload/"
rm -f "$OUTPUT_PATH"
(cd "$WORK_DIR" && /usr/bin/ditto -c -k --sequesterRsrc --keepParent Payload "$OLDPWD/$OUTPUT_PATH")

echo "Created unsigned IPA: $OUTPUT_PATH"
/usr/bin/unzip -l "$OUTPUT_PATH"
