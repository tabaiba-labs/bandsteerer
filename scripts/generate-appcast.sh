#!/bin/zsh

set -euo pipefail

if (( $# != 3 )); then
  print -u2 "Usage: $0 /path/to/generate_appcast VERSION /path/to/BandSteerer-VERSION.dmg"
  exit 64
fi

generate_appcast=$1
version=${2#v}
archive=$3

if [[ ! -x "$generate_appcast" ]]; then
  print -u2 "Sparkle's generate_appcast tool is not executable: $generate_appcast"
  exit 66
fi

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 "Version must use the X.Y.Z format."
  exit 64
fi

if [[ ! -f "$archive" || "${archive:e}" != dmg ]]; then
  print -u2 "Release archive must be an existing DMG file: $archive"
  exit 66
fi

expected_archive_name="BandSteerer-$version.dmg"
if [[ "${archive:t}" != "$expected_archive_name" ]]; then
  print -u2 "Release archive must be named $expected_archive_name."
  exit 64
fi

project_root=${0:A:h:h}
working_directory=$(mktemp -d "${TMPDIR:-/tmp}/bandsteerer-appcast.XXXXXX")
trap 'rm -rf "$working_directory"' EXIT

cp "$project_root/appcast.xml" "$working_directory/appcast.xml"
cp "$archive" "$working_directory/${archive:t}"

"$generate_appcast" \
  --account tabaiba-labs.bandsteerer \
  --download-url-prefix "https://github.com/tabaiba-labs/bandsteerer/releases/download/v$version/" \
  --link "https://github.com/tabaiba-labs/bandsteerer" \
  --maximum-deltas 0 \
  "$working_directory"

expected_url="https://github.com/tabaiba-labs/bandsteerer/releases/download/v$version/$expected_archive_name"
generated_entry=$(grep -F "url=\"$expected_url\"" "$working_directory/appcast.xml" || true)
if [[ "$generated_entry" != *'sparkle:edSignature='* ]]; then
  print -u2 "The generated entry is missing its expected URL or EdDSA signature."
  exit 65
fi

cp "$working_directory/appcast.xml" "$project_root/appcast.xml"
print "Updated $project_root/appcast.xml for v$version."
