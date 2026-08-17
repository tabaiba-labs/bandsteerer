#!/bin/zsh

set -euo pipefail

if (( $# != 3 )); then
  print -u2 "Usage: $0 VERSION /path/to/BandSteerer.app /path/to/output-directory"
  exit 64
fi

version=${1#v}
app=$2
output_directory=$3
notices="${0:A:h:h}/THIRD-PARTY-NOTICES.md"

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 "Version must use the X.Y.Z format."
  exit 64
fi

if [[ ! -d "$app" || "${app:t}" != BandSteerer.app ]]; then
  print -u2 "App must be an existing BandSteerer.app bundle: $app"
  exit 66
fi

if [[ ! -f "$notices" ]]; then
  print -u2 "Missing third-party notices: $notices"
  exit 66
fi

if ! codesign --verify --deep --strict "$app"; then
  print -u2 "BandSteerer.app must have a valid code signature before packaging."
  exit 65
fi

mkdir -p "$output_directory"
output_directory=${output_directory:A}
dmg="$output_directory/BandSteerer-$version.dmg"

if [[ -e "$dmg" ]]; then
  print -u2 "Refusing to overwrite existing release artifact: $dmg"
  exit 73
fi

staging_directory=$(mktemp -d "${TMPDIR:-/tmp}/bandsteerer-dmg.XXXXXX")
trap 'rm -rf "$staging_directory"' EXIT

ditto "$app" "$staging_directory/BandSteerer.app"
ditto "$notices" "$staging_directory/Third-Party Notices.md"
ln -s /Applications "$staging_directory/Applications"

hdiutil create \
  -srcfolder "$staging_directory" \
  -volname BandSteerer \
  -fs APFS \
  -format ULFO \
  "$dmg"

print "Created $dmg"
