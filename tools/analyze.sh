#!/usr/bin/env bash
# --> ["Kite : analyze"]
#
# Type checks the lowered package with luau-analyze.
#
# Roblox types do not exist outside Studio, so every file gets the preamble
# from Tests/analyze-preamble.luau glued to the front, and every file is
# analyzed on its own so the analyzer does not chase require() across the
# package and drag one file's Roblox types into another file's scope.
#
#   ./tools/analyze.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUAU="${ROOT}/tools/luau-src/luau-analyze"
PREAMBLE="${ROOT}/Tests/analyze-preamble.luau"
OUT="${ROOT}/build/Analyze"

if [ ! -x "$LUAU" ]; then
	echo "--> [KITE]: luau-analyze is missing, run tools/setup.sh first"
	exit 1
fi

if [ ! -d "${ROOT}/build/Luau/Kite" ]; then
	echo "--> [KITE]: building first"
	python3 "${ROOT}/build.py" --luau >/dev/null
fi

rm -rf "$OUT"
mkdir -p "$OUT"

TARGETS=()

while IFS= read -r file; do
	TARGETS+=("$file")
done < <(find "${ROOT}/build/Luau/Kite/Core" -name '*.luau' | sort)

TARGETS+=(
	"${ROOT}/build/Luau/Kite/init.luau"
	"${ROOT}/Tests/Stub.luau"
	"${ROOT}/Tests/Harness.luau"
	"${ROOT}/Tests/Reactivity.spec.luau"
	"${ROOT}/Tests/Mount.spec.luau"
	"${ROOT}/Tests/Lint.spec.luau"
	"${ROOT}/Tests/Extras.spec.luau"
	"${ROOT}/Tests/run.luau"
)

echo "--> [KITE]: analyzing ${#TARGETS[@]} file(s)"

FAILED=0
REPORTED=0

for file in "${TARGETS[@]}"; do
	name="$(basename "$file" .luau)"
	dir="$(basename "$(dirname "$file")")"

	if [ "$dir" = "Core" ]; then
		target="${OUT}/Core.${name}.luau"
	else
		target="${OUT}/${name}.luau"
	fi

	{
		cat "$PREAMBLE"
		echo ""
		echo "-- --> [\"${name}\"]"
		echo ""
		# hot comments come off: the run is nonstrict, because Roblox
		# globals cannot be declared out here
		grep -v '^--!' "$file" || true
	} >"$target"

	# Roblox types do not exist out here, and the analyzer follows require()
	# across the package into files without the preamble, so the two classes
	# of noise it cannot help are filtered. Everything else is real.
	output="$("$LUAU" --solver=old "$target" 2>&1 | grep -vE "Unknown (type|global) '|UnknownType: Unknown type|Unknown require|error-type|LocalShadow")"

	if [ -n "$output" ]; then
		REPORTED=$((REPORTED + 1))
		FAILED=$((FAILED + 1))
		echo ""
		echo "  ${name}"
		echo "$output" | sed 's/^/    /'
	fi
done

echo ""

if [ $FAILED -eq 0 ]; then
	echo "--> [KITE]: clean"
else
	echo "--> [KITE]: ${REPORTED} file(s) reported"
fi

exit $FAILED
