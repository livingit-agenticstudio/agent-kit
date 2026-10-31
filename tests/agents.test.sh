#!/bin/bash
# feature-dev-secure is feature-dev with another model and effort: their instructions must stay the same.
# Usage: tests/agents.test.sh

cd "$(dirname "$0")/.." || exit 1
body() { awk 'n >= 2 { print } /^---$/ { n++ }' "$1"; }
tools() { grep '^tools:' "$1"; }

failures=0
if [ "$(body agents/feature-dev.md)" != "$(body agents/feature-dev-secure.md)" ]; then
	echo "FAIL: agents/feature-dev-secure.md has other instructions than agents/feature-dev.md"
	failures=$((failures + 1))
fi
for agent in agents/*.md; do
	if [ "$(tools "$agent")" != "$(tools agents/feature-dev.md)" ]; then
		echo "FAIL: $agent has another tools list than agents/feature-dev.md"
		failures=$((failures + 1))
	fi
done
[ "$(grep -h '^effort:' agents/feature-dev-secure.md)" = "effort: high" ] ||
	{ echo "FAIL: feature-dev-secure is not on high effort"; failures=$((failures + 1)); }

if [ "$failures" -gt 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
