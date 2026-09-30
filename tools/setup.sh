#!/usr/bin/env bash
# --> ["Kite : setup"]
#
# Builds the Luau toolchain that the tests and the analyzer use.
# Nothing here is required to *use* Kite. It is required to test it.
#
#   ./tools/setup.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.740}"

echo "--> [KITE]: fetching Luau ${VERSION}"

cd "$ROOT/tools"

curl -sSL -o "luau-src.tar.gz" \
	"https://codeload.github.com/luau-lang/luau/tar.gz/refs/tags/${VERSION}"

tar xzf luau-src.tar.gz
rm -rf luau-src
mv "luau-${VERSION}" luau-src

echo "--> [KITE]: building (this takes a few minutes on two cores)"

make -C luau-src config=release -j2 luau luau-analyze

echo "--> [KITE]: luau and luau-analyze are in tools/luau-src"
echo "--> [KITE]: now run: python3 build.py --luau && luau Tests/run.luau"
